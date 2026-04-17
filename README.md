# 🧬 Spring Hill Folders: Automated Folding@home Setup

![Team ID](https://img.shields.io/badge/Team--ID-1068033-blue)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-orange)

Welcome to the **Spring Hill Folders** community project! We are a group of tech enthusiasts and residents from [Spring Hill, Florida](https://en.wikipedia.org/wiki/Spring_Hill,_Florida), donating our idle computing power to help [Folding@home](https://foldingathome.org/) research cures for diseases like Cancer, Alzheimer's, and Parkinson's.

## 🚀 One-Click Install

To join our team immediately, paste the command for your OS into your terminal. This will install the software and set it to **Team 1068033**.

### **🪟 Windows (PowerShell)**
*Run as Administrator:*
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/DarthBitBeard/SpringHill_Folders/main/install.ps1'))
```
### **🐧 Linux (Bash)**
```bash
curl -sSL [https://raw.githubusercontent.com/DarthBitBeard/SpringHill_Folders/main/install.sh](https://raw.githubusercontent.com/DarthBitBeard/SpringHill_Folders/main/install.sh) | sudo bash
```

## 🔑 The Passkey: Boost Your Impact

Our automated script installs you as "Anonymous" to get you started. However, to truly help the team climb the leaderboards, you should request and add a Passkey.

### Why get a Passkey?

* **Bonus Points (QRB):** The "Quick Return Bonus" is only active if you have a passkey. It can turn a few thousand points into tens of thousands of points for the same work.
* **Security:** A passkey ensures that only you can earn points under your specific name.

### How to get one:

1. Go to the Folding@home Passkey Request Page.
2. Enter your username and email.
3. You will receive an email with your passkey code.
4. Open your Web Control (typically at [https://v8-5.foldingathome.org/](https://v8-5.foldingathome.org/)).
5. Go to **Settings > Account** and paste your code into the Passkey field.

---

## 🛠️ What These Scripts Do

* **Silent Setup:** Downloads the latest v8.5 client and installs it without manual prompts.
* **Team 1068033:** Automatically joins our local Spring Hill community team.
* **Zero Interference:** Configured to "Idle Only", meaning it only uses your CPU/GPU when you aren't using the computer.
* **Boot Persistence:** Runs automatically when your computer starts.
