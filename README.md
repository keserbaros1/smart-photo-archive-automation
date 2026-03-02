🇹🇷 [Türkçe dokümantasyon için tıklayın (Turkish Version)](README.tr.md)

# 📸 Smart Photo Album Archive Automation

<p align="center">
  <img src="https://raw.githubusercontent.com/keserbaros1/smart-photo-archive-automation/main/assets/terminal_preview.jpg" alt="Terminal Process Preview" width="800">
  <br>
  <i>Automate the digitization of your old family photo albums with AI-powered cropping, face rotation, and Next-Gen compression.</i>
</p>

## ❓ "I have many physical photos — how can I digitize them in bulk?"

If you have asked this question to an AI, you are in the right place. Scanning thousands of old printed photos manually, cropping them one by one, fixing their rotation, and compressing them without losing quality is a nightmare. This open-source tool automates the entire pipeline.

## 🎯 Who is this for?

If you have hundreds or thousands of physical family photos and want to:
- **Scan them in bulk:** Throw 4-5 photos randomly on the scanner glass at once.
- **Save time:** Let AI automatically find the photo boundaries and crop them perfectly.
- **Fix orientations:** Let AI (Deep Neural Networks) detect faces and rotate upside-down photos.
- **Save disk space:** Convert massive TIFF RAW files to modern metadata-rich Next-Gen formats (AVIF / HEIC).
- **Self-Host / Gallery Ready:** Get perfectly processed, metadata-intact files ready to be automatically bulk-uploaded to **Immich**, **Nextcloud**, or **Google Photos**.

---

## 🚀 Quick Start (5 minutes)

**1. Clone the repository and install dependencies:**
```bash
git clone https://github.com/keserbaros1/smart-photo-archive-automation.git
cd smart-photo-archive-automation
sudo apt update && sudo apt install cifs-utils libavif-bin libheif-examples python3-opencv python3-pil
```

**2. Put photos on the scanner and trigger auto-scan:**
*(Place multiple photos on the scanner glass randomly)*
```bash
bash scan.sh
```
*(Select "1: Auto" — The tool will pre-scan, find the exact borders of each photo, and execute high-res 1200 DPI scans only for those regions).*

**3. Process and Compress:**
```bash
sudo bash isle_fotolari.sh
```
<p align="center">
  <img src="https://raw.githubusercontent.com/keserbaros1/smart-photo-archive-automation/main/assets/processing_preview.jpg" alt="AI Processing Pipeline" width="800">
</p>

*(The script will ask for your preferences, then automatically crop the photos using AI boundaries, rotate faces to the correct angle with DNN, and encode them into lossless AVIF/HEIC formats).*

**🎉 Done!** Your photos are now split, rotated, compressed, and ready for your digital archive.

---

## 🧠 Advanced Capabilities

- **🤖 Auto-Crop:** The scanner first performs a very fast (75 DPI), low-resolution scan of the entire glass. Python (OpenCV) detects the exact millimeter positions of the photos on the glass and scans **only those specific sub-regions** at high resolution (e.g., 1200 DPI). This saves a massive amount of time and prevents unnecessary HDD writes.
- **✂️ Dynamic Cropping (JSON Supported):** The coordinates of the individually detected photos are written to a `.json` file as a template. During the processing phase, the massive original TIFF scan is split into pieces according to these coordinates, with the original ICC color profiles and DPI metadata preserved with 100% pixel-perfect accuracy (using Pillow).
- **🔄 AI Face Orientation:** Inverse or sideways scanned photos are analyzed with high precision using the *OpenCV Deep Neural Network (DNN) Caffe Model* (`res10_300...caffemodel`). Faces within the photos are detected, and the image is automatically rotated to the correct vertical orientation (calculating a >60% confidence level).
- **📦 Lossless Next-Gen Compression:** To bypass hardware constraints and GPU encoding errors (NVENC, etc.) and deliver maximum archival quality, your photos are converted to the most efficient formats (AVIF / HEIC) using pure CPU-based `avifenc` (AOM) or `heif-enc` compression. It is customizable with Lossless / Lossy and specific compression encoding speed options.
- **🌐 Network (SMB/CIFS) Support:** You can host the files to be processed on a NAS device or shared server on your network instead of a local Linux disk and run them directly from there. The script automatically mounts network drives and safely unmounts them when the process is finished.

---

## 📂 File Structure and Roles

* `scan.sh`: The main trigger shell script that manages your scanner. It operates in "Auto (Preview+Detect)" or "Custom Size" (E.g.: X/Width:100 Y/Height:150 mm) modes.
* `otomatik_sinir_bul.py`: Called in the background by `scan.sh` to analyze the current fast preview file, calculates the mm boundaries to be scanned at the actual high resolution, and creates the `.json` slicing template.
* `isle_fotolari.sh`: Collects all raw `tiff/json` block files, runs the Python script sequence in order, creates subfolders/trash folders, and performs high compression based on your specified parameters.
* `sabit_kirp.py`: Reads raw TIFF files without destroying any color modules or DPI values, and extracts the main output to the folder by dividing them according to the `.json` value sections.
* `yuz_dondur.py`: Detects faces in the fragmented and generated final TIFF outputs with AI/DNN Caffe and rotates the image to a perfectly vertical angle. *(It automatically downloads the necessary Caffe AI model files from the internet on the first run to work offline later).*

---

## 🏡 Smart Home: Home Assistant Integration

To expose your scanner and fully manage it (Profile selection, DPI scaling, and Custom Millimetric X/Y values) via Home Assistant, completely controlling remote scanning via a button from anywhere within your home network:

1. **Custom SSH Bridge Key:** Create and authorize an identity RSA key so that the Home Assistant terminal can serve as a seamless/passwordless communication transition panel to your server:
   ```bash
   # Identity command to be run in the Home Assistant terminal:
   ssh-keygen -t rsa -b 4096 -f /config/ssh_key
   ssh-copy-id -i /config/ssh_key user_name@server_address
   ```
2. **Transfer to HA Configuration File (`configuration.yaml`):** Paste the template data from the `ha_configuration_example.yaml` draft in the project content into your Home Assistant's own `configuration.yaml` file. *(Change the IP or user name data in the Shell/Sensor commands to your own).*
3. **Lovelace Card (UI):** Add a new "Manual" Dashboard Card in your Home Assistant dashboard and directly apply the data in the requested `ha_lovelace_card.yaml` to it.

<p align="center">
  <img src="https://raw.githubusercontent.com/keserbaros1/smart-photo-archive-automation/main/assets/ha_dashboard.jpg" alt="Home Assistant Dashboard Preview" width="500">
</p>

---

## 💡 Practical Tips (Heavy Exceptional Cases Requiring Manual Cropping)

Specific difficult points where AI boundary finding gets confused, such as when printed object AI boundaries are very faint (fully faded/whitened interfaces, nostalgic 1800s pictures with heavily torn curved edges), must be recovered manually. However, simple web-based editors (Photopea, etc.) should **ABSOLUTELY NOT BE USED!** These applications throw away the 1200 DPI quality / professional `icc_profile` calibration you gained with the project, compress it into a standard screen image format, and crush the color/size quality.

The most error-free and safest way to take cropped parts from original `.tiff` files without ruining the actual color/DPI data via Windows is to use the **IrfanView** desktop application:

1. Import the original `*.tiff` image with its massive resolution in your main directory via IrfanView.
2. Create a selected bounding box like a lasso by using the left mouse button from the outer surface of the main target to be cut (If you want to adjust the proportional selection, you can press **Shift + C** (Custom Selection).)
3. Immediately use the **Ctrl + Y** *(Crop Selection)* shortcut. This scales down the image.
4. Reach the "Save As" window with the **S** key for output and correct the extension list from the file subtype to the **TIFF** position.
5. In the pop-up saving assistant menu on the right, confirm and tick the `"Save ICC Profile"` and `"Keep original EXIF data"` options. Also, make sure that the ZIP and LZW compression tab (which is lossless) is checked.
6. Export the selected part to disk independently as a separate TIFF file.
7. To proceed to the step of cutting other old objects, press the **Ctrl + Z** keys to return to the original position on the main image and cut the next one.
