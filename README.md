🇹🇷 [Türkçe dokümantasyon için tıklayın (Turkish Version)](README.tr.md)

# 📸 Smart Photo Album Archive Automation

This project is an end-to-end automation system designed to scan your old printed photos at the highest quality (RAW TIFF) using SANE (`scanimage`), automatically crop them using **AI-powered boundary detection**, automatically correct their orientation using **face analysis**, and losslessly compress them into next-generation formats (AVIF/HEIC).

Furthermore, with its fully integrated **Home Assistant** interface, you can manage the entire scanning process directly from your mobile phone without ever needing to sit at a physical computer.

---

## 🚀 Advanced Features

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

## 🛠️ Installation and System Requirements

The project is designed to run smoothly on Debian/Ubuntu-based systems (Native Linux distributions or WSL environments).
When the installer script (`isle_fotolari.sh`) is run for the first time, it checks the main required dependencies and automatically installs any missing ones via APT.

If you want to install them manually in different configurations:
```bash
sudo apt-get update
sudo apt-get install cifs-utils libavif-bin libheif-examples python3-opencv python3-pil
```
*(Note: The `.prototxt` and `.caffemodel` machine learning weight files required for AI Face recognition are automatically downloaded and used by the `yuz_dondur.py` module only when needed by the system).*

---

## 💻 System Usage

### 1. Scanning Photos into the System (`scan.sh`)
Run the following trigger directly in the main Linux terminal attached to your scanner:
```bash
bash scan.sh
```
When you select the "**Otomatik (Auto)**" option from the menu, the positional boundaries of all the photos you randomly placed side-by-side on the scanner glass are detected by AI. Only those specific detected focal points are scanned at high resolution (saving time), and they are saved in the raw output folder under the prefix `scan_X...` alongside a fully compatible `.json` module file containing those coordinates.
You can also choose customized millimeter dimensions directly from the menu to ensure a fixed scan within your own drawn area.

### 2. Processing Scanned Photos as Data (`isle_fotolari.sh`)
To convert the whole queue of raw `.tiff` and `.json` planted files mirrored in the remote folder into final end-user formats (AI cropping, Caffe Face Rotation, etc.), call the script once with `sudo` privileges in the terminal (*the system permissions of the output files will not be locked in the sudo phase, they will belong to your natural account that operates that part*):
```bash
sudo bash isle_fotolari.sh
```
The script console will ask you in interactive steps: (Local or Network File path, date masking/selection, AVIF or HEIC / Lossless / Compression Engine Speed). Once it passes through these filters, it locks its assignment and finalizes the photos in a fully automated background process.

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

Congratulations, you can set up a scanning operation extremely securely with all devices inside your house without physically going to a monitor or terminal stack!

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

*(The machine will similarly understand these portions of tiff files you manually divided/extracted, process them through the \`isle_fotolari.sh\` process panel with filters such as quality, straight rotation, etc., and will continue natively to give the usual final AVIF/HEIC format outputs automatedly.)*
