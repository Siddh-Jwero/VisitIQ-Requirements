# VisitIQ Model Flow Architecture

This document provides a comprehensive overview of the AI/ML model pipeline and processing flow in the VisitIQ retail analytics system.

## High-Level System Flow

```mermaid
flowchart TB
    subgraph Input["📹 Input Sources"]
        USB["USB Camera"]
        RTSP["RTSP Stream"]
        VID["Video Files"]
    end

    subgraph Preprocessing["🔧 Preprocessing (OpenCV)"]
        CAP["cv2.VideoCapture"]
        RESIZE["Frame Downscaling"]
        BGR["BGR Format"]
    end

    subgraph Detection["🎯 Object Detection"]
        YOLO["YOLO v8/v11<br/>(Ultralytics)"]
        PDET["Person Detection<br/>class_id=0"]
        CDET["Chair Detection<br/>class_id=56"]
        CUPDET["Cup Detection<br/>class_id=41"]
    end

    subgraph Tracking["📍 Object Tracking"]
        TRACKER["SimpleTracker<br/>(Centroid + Hungarian Algorithm)"]
        NMS["Non-Max Suppression"]
        IOU["IoU Assignment"]
        VELOCITY["Velocity Prediction"]
    end

    subgraph FaceEmbedding["👤 Face Embedding Pipeline"]
        ADAFACE["AdaFace<br/>(InsightFace buffalo_l)"]
        DEEPFACE["DeepFace<br/>(Facenet512)"]
        HAAR["Haar Cascade<br/>(Fallback)"]
    end

    subgraph AgeGender["🎂 Age/Gender Detection"]
        HFGENDER["HF ViT Gender Classifier<br/>(rizvandwiki/gender-classification)"]
        DFAGE["DeepFace Age<br/>(TensorFlow)"]
    end

    subgraph BodyContext["👔 Body/Context Embedding"]
        CLIP["CLIP ViT-B/32<br/>(OpenAI)"]
        BODY["Body Embedding"]
        CONTEXT["Context Embedding"]
    end

    subgraph Fusion["🔀 Embedding Fusion"]
        MULTI["MultiModalEmbedder"]
        WEIGHTS["Weighted Fusion<br/>Face: 60% | Body: 25% | Context: 10%"]
    end

    subgraph Matching["🔄 Customer Matching"]
        REGISTRY["GlobalCustomerRegistry<br/>(SQLite)"]
        COSINE["Cosine Similarity"]
        CACHE["In-Memory Cache"]
    end

    subgraph Output["📊 Output"]
        ANALYTICS["Analytics Summary"]
        PHOTOS["Customer Photos"]
        CRM["CRM Integration"]
    end

    %% Flow connections
    USB & RTSP & VID --> CAP
    CAP --> RESIZE
    RESIZE --> BGR
    BGR --> YOLO
    YOLO --> PDET & CDET & CUPDET
    PDET --> NMS
    NMS --> TRACKER
    TRACKER --> IOU & VELOCITY
    
    PDET --> ADAFACE
    ADAFACE -->|"Primary"| Fusion
    PDET --> DEEPFACE
    DEEPFACE -->|"Fallback"| Fusion
    DEEPFACE -->|"Last Resort"| HAAR
    
    PDET --> HFGENDER
    PDET --> DFAGE
    HFGENDER & DFAGE --> AgeGenderResults["Age/Gender Results"]
    
    PDET --> CLIP
    CLIP --> BODY & CONTEXT
    BODY & CONTEXT --> Fusion
    
    Fusion --> MULTI
    MULTI --> WEIGHTS
    WEIGHTS --> COSINE
    COSINE --> REGISTRY
    REGISTRY --> CACHE
    
    TRACKER & REGISTRY & AgeGenderResults --> ANALYTICS
    ANALYTICS --> PHOTOS & CRM
```

---

## Detailed Model Components

### 1. Object Detection - YOLO

```mermaid
flowchart LR
    subgraph YOLO_Pipeline["YOLO Detection Pipeline"]
        INPUT["BGR Frame<br/>640x640"]
        
        subgraph Model["YOLO Model Options"]
            PT["yolov8n.pt / yolov11n.pt<br/>(PyTorch)"]
            COREML["yolov8n.mlpackage<br/>(CoreML - Apple Silicon)"]
            TRTENG["yolov8n.engine<br/>(TensorRT - NVIDIA)"]
        end
        
        INFERENCE["Inference<br/>conf_thr=0.40"]
        
        subgraph Classes["Detected Classes"]
            PERSON["Person (ID: 0)"]
            CHAIR["Chair (ID: 56)"]
            CUP["Cup (ID: 41)"]
        end
        
        BBOXES["Bounding Boxes<br/>[x1, y1, x2, y2]"]
    end
    
    INPUT --> PT & COREML & TRTENG
    PT & COREML & TRTENG --> INFERENCE
    INFERENCE --> PERSON & CHAIR & CUP
    PERSON & CHAIR & CUP --> BBOXES
```

**Key Parameters:**
| Parameter | Value | Description |
|-----------|-------|-------------|
| `DETECTION_CONF_THR` | 0.40 | Person detection confidence |
| `CHAIR_DETECTION_CONF_THR` | 0.45 | Chair detection confidence |
| `CUP_DETECTION_CONF_THR` | 0.45 | Cup detection confidence |
| `YOLO_IMGSZ` | 640 | Inference image size |

---

### 2. Object Tracking - SimpleTracker

```mermaid
flowchart TB
    subgraph Tracker["SimpleTracker Algorithm"]
        INPUT2["Detected Bboxes"]
        
        NMS2["Non-Max Suppression<br/>IoU_thr=0.3, dist_thr=50"]
        
        subgraph Assignment["Track Assignment"]
            DIST["Distance Matrix<br/>(Centroid Distance)"]
            IOUMAT["IoU Matrix"]
            HUNGARIAN["Hungarian Algorithm"]
        end
        
        subgraph State["Track State"]
            ACTIVE["Active Tracks"]
            DISAPPEARED["Disappeared Counter"]
            VELOCITY2["Velocity Estimation"]
        end
        
        REGISTER["Register New Tracks"]
        DEREGISTER["Deregister Lost Tracks<br/>(MAX_DISAPPEARED=120)"]
        
        SESSIONS["Session Building"]
    end
    
    INPUT2 --> NMS2
    NMS2 --> DIST & IOUMAT
    DIST & IOUMAT --> HUNGARIAN
    HUNGARIAN --> ACTIVE & DISAPPEARED & VELOCITY2
    ACTIVE --> REGISTER
    DISAPPEARED --> DEREGISTER
    ACTIVE --> SESSIONS
```

**Key Parameters:**
| Parameter | Value | Description |
|-----------|-------|-------------|
| `MAX_DISAPPEARED` | 120 | Frames before track removal (~4s at 30fps) |
| `ASSIGN_DIST` | 220.0 | Max distance for track assignment |
| `IOU_ASSIGNMENT_THRESHOLD` | 0.25 | IoU threshold for assignment |

---

### 3. Face Embedding Pipeline

```mermaid
flowchart TB
    subgraph FacePipeline["Face Embedding Extraction"]
        PERSON_BBOX["Person Bbox"]
        FACE_REGION["Face Region<br/>(Upper 30% of bbox)"]
        
        subgraph Primary["Primary: AdaFace (InsightFace)"]
            INSIGHT["InsightFace FaceAnalysis<br/>(buffalo_l model)"]
            ONNX["ONNX Runtime"]
            ADAEMB["512-dim Embedding"]
        end
        
        subgraph Secondary["Fallback: DeepFace"]
            FACENET["Facenet512 Model"]
            TF["TensorFlow Backend"]
            DFEMB["512-dim Embedding"]
        end
        
        subgraph Tertiary["Last Resort: Haar Cascade"]
            HAAR2["cv2.CascadeClassifier"]
            PIXEL["Pixel Descriptor"]
        end
        
        OUTPUT_EMB["Normalized Face Embedding"]
    end
    
    PERSON_BBOX --> FACE_REGION
    FACE_REGION --> INSIGHT
    INSIGHT --> ONNX --> ADAEMB
    ADAEMB -->|"Success"| OUTPUT_EMB
    
    FACE_REGION -->|"AdaFace Fails"| FACENET
    FACENET --> TF --> DFEMB
    DFEMB -->|"Success"| OUTPUT_EMB
    
    FACE_REGION -->|"DeepFace Fails"| HAAR2
    HAAR2 --> PIXEL
    PIXEL --> OUTPUT_EMB
```

---

### 4. Age & Gender Detection

```mermaid
flowchart TB
    subgraph AgeGenderPipeline["Age/Gender Detection Pipeline"]
        FACE_CROP["Face Crop<br/>(Multiple Strategies)"]
        
        subgraph GenderPipeline["Gender Classification"]
            HFVIT["HuggingFace ViT<br/>(rizvandwiki/gender-classification)"]
            TRANSFORM["Transformers AutoModel"]
            GENDER_OUT["Male/Female + Confidence"]
        end
        
        subgraph AgePipeline["Age Estimation"]
            DFANALYZE["DeepFace.analyze()"]
            ACTIONS["actions=['age']"]
            AGE_CORRECT["Age Correction<br/>(Bias Adjustment)"]
            AGE_OUT["Corrected Age"]
        end
        
        subgraph Aggregation["Multi-Sample Aggregation"]
            SAMPLES["Multiple Face Crops"]
            VOTING["Weighted Voting"]
            FINAL["Final Age/Gender"]
        end
    end
    
    FACE_CROP --> HFVIT
    HFVIT --> TRANSFORM --> GENDER_OUT
    
    FACE_CROP --> DFANALYZE
    DFANALYZE --> ACTIONS --> AGE_CORRECT --> AGE_OUT
    
    GENDER_OUT & AGE_OUT --> SAMPLES
    SAMPLES --> VOTING --> FINAL
```

**Key Models:**
| Model | Source | Purpose | Accuracy |
|-------|--------|---------|----------|
| ViT Gender Classifier | HuggingFace rizvandwiki | Gender classification | 92.4% |
| DeepFace Age | DeepFace library | Age estimation | ~5 years MAE |

---

### 5. Body/Context Embedding - CLIP

```mermaid
flowchart TB
    subgraph CLIPPipeline["CLIP Embedding Pipeline"]
        PERSON_IMG["Person Crop"]
        
        subgraph CLIPModel["CLIP ViT-B/32"]
            VIT["Vision Transformer"]
            PROJ["Projection Layer"]
            NORM["L2 Normalization"]
        end
        
        subgraph Embeddings["Extracted Embeddings"]
            BODY_EMB["Body Embedding<br/>(Person bbox)"]
            CTX_EMB["Context Embedding<br/>(2x expanded region)"]
            FACE_REG["Face Region Embedding<br/>(Upper body backup)"]
        end
        
        OUT512["512-dim Embeddings"]
    end
    
    PERSON_IMG --> VIT
    VIT --> PROJ --> NORM
    NORM --> BODY_EMB & CTX_EMB & FACE_REG
    BODY_EMB & CTX_EMB & FACE_REG --> OUT512
```

**Captured Features:**
- Clothing patterns and colors
- Body shape and posture
- Scene context (counter, display area, etc.)
- Background elements for location association

---

### 6. Multi-Modal Embedding Fusion

```mermaid
flowchart TB
    subgraph MultiModal["MultiModalEmbedder"]
        subgraph Inputs["Input Embeddings"]
            FACE_IN["Face Embedding<br/>(AdaFace/DeepFace)"]
            BODY_IN["Body Embedding<br/>(CLIP)"]
            CTX_IN["Context Embedding<br/>(CLIP)"]
        end
        
        subgraph Weights["Fusion Weights"]
            DEFAULT_W["Default Weights<br/>Face: 60% | Body: 25% | Context: 10%"]
            NOFACE_W["No-Face Weights<br/>Body: 70% | Context: 30%"]
            FACEONLY_W["Face-Only Weights<br/>Face: 100%"]
        end
        
        ADAPTIVE["Adaptive Weight Selection"]
        
        FUSED["Fused 512-dim Embedding"]
    end
    
    FACE_IN & BODY_IN & CTX_IN --> ADAPTIVE
    DEFAULT_W & NOFACE_W & FACEONLY_W --> ADAPTIVE
    ADAPTIVE --> FUSED
```

**Fusion Strategy:**
```
Fused = w_face × E_face + w_body × E_body + w_context × E_context
```

---

### 7. Customer Matching & Registry

```mermaid
flowchart TB
    subgraph Registry["GlobalCustomerRegistry"]
        QUERY_EMB["Query Embedding"]
        
        subgraph Storage["SQLite Storage"]
            DB["global_customers.db"]
            EMBEDDINGS_TABLE["customer_embeddings table"]
            CUSTOMERS_TABLE["customers table"]
        end
        
        subgraph Cache["In-Memory Cache"]
            EMB_MATRIX["Embedding Matrix<br/>(N × 512)"]
            CUST_IDS["Customer ID Mapping"]
        end
        
        subgraph Matching["Matching Algorithm"]
            COSINE2["Vectorized Cosine Similarity"]
            THRESHOLD["Threshold: 0.58"]
            TOPK["Top-K Candidates"]
        end
        
        subgraph Results["Results"]
            EXISTING["Existing Customer<br/>(CUST-{uuid})"]
            NEW["New Customer<br/>(Generate UUID)"]
        end
    end
    
    QUERY_EMB --> COSINE2
    EMB_MATRIX --> COSINE2
    COSINE2 --> THRESHOLD --> TOPK
    TOPK --> EXISTING
    TOPK -->|"No Match"| NEW
    
    DB --> EMB_MATRIX
    DB --> CUST_IDS
```

**Key Parameters:**
| Parameter | Value | Description |
|-----------|-------|-------------|
| `MATCH_THRESHOLD_DEFAULT` | 0.58 | Minimum similarity for match |
| `MAX_EMBEDDINGS_PER_CUSTOMER` | 10 | Embeddings stored per customer |
| `CACHE_REFRESH_INTERVAL_SEC` | 300 | Cache refresh interval (5 min) |

---

## Device Configuration & Hardware Acceleration

```mermaid
flowchart TB
    subgraph DeviceConfig["Device Configuration (device_config.py)"]
        DETECT["Device Detection"]
        
        subgraph Priority["Priority Order"]
            CUDA["1. CUDA (NVIDIA GPU)"]
            MPS["2. MPS (Apple Silicon)"]
            CPU["3. CPU (Fallback)"]
        end
        
        subgraph Frameworks["Framework-Specific Config"]
            PYTORCH["PyTorch<br/>(YOLO, CLIP, HF)"]
            TF_GPU["TensorFlow<br/>(DeepFace)"]
            ONNX_RT["ONNX Runtime<br/>(InsightFace)"]
        end
    end
    
    DETECT --> CUDA & MPS & CPU
    CUDA & MPS & CPU --> PYTORCH & TF_GPU & ONNX_RT
```

**ONNX Execution Providers:**
| Device | Provider |
|--------|----------|
| NVIDIA CUDA | CUDAExecutionProvider |
| Apple MPS | CoreMLExecutionProvider |
| CPU | CPUExecutionProvider |

---

## Complete Pipeline Summary

```mermaid
flowchart LR
    subgraph Pipeline["Complete Processing Pipeline"]
        A["📹 Video Frame"] --> B["🔧 OpenCV<br/>Preprocess"]
        B --> C["🎯 YOLO<br/>Detection"]
        C --> D["📍 SimpleTracker<br/>Tracking"]
        D --> E["👤 Face Pipeline<br/>AdaFace/DeepFace"]
        E --> F["🎂 Age/Gender<br/>HF-ViT/DeepFace"]
        D --> G["👔 CLIP<br/>Body/Context"]
        E & G --> H["🔀 Multi-Modal<br/>Fusion"]
        H --> I["🔄 Customer<br/>Registry"]
        D & F & I --> J["📊 Analytics<br/>Output"]
    end
```

---

## Library Dependencies

| Component | Library | Version | Purpose |
|-----------|---------|---------|---------|
| Object Detection | ultralytics | Latest | YOLO v8/v11 |
| Image Processing | opencv-python | Latest | Frame capture, preprocessing |
| Face Recognition | deepface | Latest | Face analysis, age estimation |
| Face Embeddings | insightface | ≥0.7.3 | AdaFace embeddings |
| ONNX Inference | onnxruntime | Latest | InsightFace backend |
| Body Embeddings | CLIP (OpenAI) | git | Context/body features |
| Gender Classification | transformers | Latest | HuggingFace ViT model |
| Deep Learning | torch | ≥2.0.0 | PyTorch backend |
| Image Utils | Pillow | Latest | Image format conversion |
| Scientific Computing | numpy, scipy | Latest | Array operations |

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `YOLO_IMGSZ` | 640 | YOLO inference image size |
| `ADAFACE_ENABLED` | 1 | Enable AdaFace embedder |
| `HFGENDER_ENABLED` | 0 | Enable HuggingFace gender classifier |
| `MULTIMODAL_ENABLED` | 0 | Enable multi-modal fusion |
| `CLIP_ENABLED` | 1 | Enable CLIP embeddings |
| `ENABLE_AGE_GENDER` | 1 | Enable age/gender detection |
