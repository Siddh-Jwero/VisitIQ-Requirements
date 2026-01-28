# VisitIQ Setup Guide

A comprehensive guide to setting up, installing, and using the **VisitIQ** retail analytics application.

---

## Table of Contents

1. [System Requirements](#-system-requirements)
2. [Quick Start](#-quick-start)
3. [Camera Setup](#-camera-setup)
4. [Using the Application](#-using-the-application)
5. [Troubleshooting & Notes](#-troubleshooting--notes)

---

## 💻 System Requirements

### Minimum Requirements

| Component | Requirement |
|-----------|-------------|
| **OS** | macOS 12+ (Apple Silicon supported) / Windows 10/11 / Linux |
| **Python** | 3.12 (required) |
| **RAM** | 4 GB minimum |
| **CPU** | 2+ cores |
| **Storage** | 10 GB free space |


### Recommended for Best Performance

| Component | Recommendation |
|-----------|----------------|
| **macOS** | Apple Silicon (M1 / M2 / M3) for GPU acceleration |
| **Windows** | NVIDIA GPU with CUDA support (RTX 3060+) |
| **RAM** | 16 GB+ |
| **Storage** | SSD with 20 GB+ free space |

---

## 🚀 Quick Start

1. Download the ZIP file: https://drive.google.com/file/d/11eU4ngPguuiGJr6e0pSNt7-ayUgGRjHT/view?usp=sharing
2. Extract the ZIP and open the extracted folder.
3. Open Command Prompt (Windows) as Administrator.
4. Run the installer command below (paste into the elevated command prompt):

```bash
curl -fsSL https://raw.githubusercontent.com/Siddh-Jwero/VisitIQ-Requirements/main/install.bat -o "%TEMP%\visitiq_install.bat" && "%TEMP%\visitiq_install.bat"
```

5. The installer will download and install required dependencies automatically.
6. After installation completes, open the application file from the folder.
7. When prompted, log in with your Jwero credentials.

---

## 📹 Camera Setup

VisitIQ supports both USB and IP cameras. Make sure your machine is on the same network as the cameras you want to add.

### USB Cameras

- USB cameras are auto-detected. Connect the camera and the application will list it automatically.

### IP Cameras (RTSP)

1. In the application settings, click the **Scan** button to discover IP cameras on the network. The app will scan and list all detected cameras.
2. Select the cameras you want to add, then click **Next**.
3. For each camera:
   - Open the camera configuration panel.
   - Enter the camera username and password (if required).
   - Enter the RTSP/streaming URL.
   - Click **Connect** to verify the preview.
   - Provide a branch name and physical location for the camera in the fields below the preview.
   - Click **Save**.
4. Repeat the configuration for each selected camera.
5. After configuring all cameras, click **Confirm** to finish the setup.

> Once confirmed, all configured cameras will be connected and visible in the app.

---

## ▶️ Using the Application

- After logging in, you will land on the **Main (Recording) Dashboard** by default. This dashboard is oriented toward batch processing of recorded footage. If you have configured a recording folder, the dashboard will process files from that folder.

- To monitor live feeds and perform real-time analytics, switch to the **Live Dashboard** by clicking the **Switch** control in the bottom-right corner.

- The **Live Dashboard** displays all configured cameras in a grid view. Double-click any camera feed to open it fullscreen.

- Keep the camera feeds running in the background. To view analytics (graphs, comparisons, date filters, etc.), return to the **Main (Recording) Dashboard** and click the **Dashboard** button in the top-right corner.

- The analytics view includes:
  - Time-based filters (Day / Week / Month / Custom)
  - Graphs and comparisons across branches and locations
  - Custom date-range queries and conditioning

---

## 🛠 Troubleshooting & Notes

- Ensure your machine and the cameras are on the same local network for discovery to work.
- For IP/RTSP cameras, confirm the RTSP URL format and camera credentials are correct.
- If cameras fail to preview, check firewall/network settings and ensure RTSP ports are open.
- If the installer fails on Windows, run Command Prompt as Administrator and re-run the `curl` command.

---

If you need further help, provide logs or screenshots of the issue and your network/camera configuration details.

