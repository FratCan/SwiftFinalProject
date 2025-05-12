import UIKit
import AVFoundation
import ContactsUI
import MessageUI
import MobileCoreServices
import CoreImage

class ViewController: UIViewController, CNContactPickerDelegate, MFMessageComposeViewControllerDelegate, UIDocumentPickerDelegate, AVCaptureMetadataOutputObjectsDelegate {


    var scannedText: String?
    var selectedPhoneNumber: String?
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession?.stopRunning()
        previewLayer?.removeFromSuperlayer()

        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           metadataObject.type == .qr,
           let stringValue = metadataObject.stringValue {
            scannedText = stringValue

            let alert = UIAlertController(title: "QR Mesajı", message: stringValue, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Tamam", style: .default) { _ in
                if self.selectedPhoneNumber != nil {
                    self.showConfirmationBeforeSendingSMS()
                } else {
                    let info = UIAlertController(title: "Kişi Seçin", message: "Mesajı göndermek için bir kişi seçmeniz gerekiyor.", preferredStyle: .alert)
                    info.addAction(UIAlertAction(title: "Tamam", style: .default))
                    self.present(info, animated: true)
                }
            })
            present(alert, animated: true)
        } else {
            showAlert(title: "QR Kod Bulunamadı", message: "Kamera ile QR kod algılanamadı.")
        }
    }
    
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Tamam", style: .default))
        present(alert, animated: true)
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle()
        setupButtons()
    }

    func setupButtons() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let selectContactButton = createStyledButton(title: "📇 Kişi Seç", width: 200)
        selectContactButton.addTarget(self, action: #selector(selectContactTapped), for: .touchUpInside)
        
        let loadQRCodeButton = createStyledButton(title: "📷 QR Kod Yükle", width: 200)
        loadQRCodeButton.addTarget(self, action: #selector(loadQRCodeTapped), for: .touchUpInside)
        
        let scanFromCameraButton = createStyledButton(title: "📷 Kameradan Tara", width: 200)
        scanFromCameraButton.addTarget(self, action: #selector(scanFromCameraTapped), for: .touchUpInside)
        
        let backButton = createStyledButton(title: "🔙 Geri", width: 200, backgroundColor: .systemRed)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        stackView.addArrangedSubview(scanFromCameraButton)
        stackView.addArrangedSubview(loadQRCodeButton)
        stackView.addArrangedSubview(selectContactButton)
        stackView.addArrangedSubview(backButton)


        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc func scanFromCameraTapped() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              (captureSession?.canAddInput(videoInput) ?? false) else {
            showAlert(title: "Kamera Hatası", message: "Kamera girişine erişilemiyor.")
            return
        }

        captureSession?.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession?.canAddOutput(metadataOutput) ?? false {
            captureSession?.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            showAlert(title: "Hata", message: "QR kod tarama desteklenmiyor.")
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer!)

        captureSession?.startRunning()
    }

    func createStyledButton(title: String, width: CGFloat, backgroundColor: UIColor = .systemBlue) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = backgroundColor
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        
        // Gölge efekti
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.2
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        
        return button
    }
    func setupTitle() {
        let titleLabel = UILabel()
        titleLabel.text = "QR Code Scanner to Message"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Gölge efekti (isteğe bağlı)
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOpacity = 0.2
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        titleLabel.layer.shadowRadius = 2

        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }



    @objc func selectContactTapped() {
        let contactPicker = CNContactPickerViewController()
        contactPicker.delegate = self
        present(contactPicker, animated: true)
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        if let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
            selectedPhoneNumber = phoneNumber
            showConfirmationBeforeSendingSMS()
        }
    }

    @objc func loadQRCodeTapped() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let fileURL = urls.first else { return }
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            if let qrCodeString = extractQRCode(from: fileData) {
                scannedText = qrCodeString
                let alert = UIAlertController(title: "QR Mesajı", message: qrCodeString, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Tamam", style: .default) { _ in
                    if self.selectedPhoneNumber != nil {
                        self.showConfirmationBeforeSendingSMS()
                    } else {
                        let info = UIAlertController(title: "Kişi Seçin", message: "Mesajı göndermek için bir kişi seçmeniz gerekiyor.", preferredStyle: .alert)
                        info.addAction(UIAlertAction(title: "Tamam", style: .default))
                        self.present(info, animated: true)
                    }
                })
                present(alert, animated: true)
            } else {
                let alert = UIAlertController(title: "Geçersiz QR Kod", message: "QR kodu çözülemedi.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Tamam", style: .default))
                present(alert, animated: true)
            }
        } catch {
            print("Dosya okuma hatası: \(error)")
        }
    }

    // QR kodu çözümleme işlemi için CIDetector kullanma
    func extractQRCode(from data: Data) -> String? {
        guard let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else {
            print("Görsel verisi alınamadı.")
            return nil
        }

        let ciImage = CIImage(cgImage: cgImage)

        let detector = CIDetector(ofType: CIDetectorTypeQRCode,
                                  context: nil,
                                  options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])

        guard let features = detector?.features(in: ciImage) else {
            print("Feature alınamadı.")
            return nil
        }

        for feature in features {
            if let qrFeature = feature as? CIQRCodeFeature,
               let message = qrFeature.messageString {
                return message
            }
        }

        return nil
    }


    func showConfirmationBeforeSendingSMS() {
        guard let text = scannedText else {
            let alert = UIAlertController(title: "QR Kodu Gerekli", message: "Lütfen önce bir QR kod yükleyin.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Tamam", style: .default))
            present(alert, animated: true)
            return
        }
        
        guard let phone = selectedPhoneNumber else {
            let alert = UIAlertController(title: "Kişi Eksik", message: "Lütfen bir kişi seçin.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Tamam", style: .default))
            present(alert, animated: true)
            return
        }
        
        let alert = UIAlertController(title: "Mesajı Gönder", message: "Bu mesajı kişiye göndermek istiyor musunuz?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Gönder", style: .default) { _ in
            self.sendSMS(phoneNumber: phone, message: text)
        })
        alert.addAction(UIAlertAction(title: "İptal", style: .cancel))
        present(alert, animated: true)
    }

    func sendSMS(phoneNumber: String, message: String) {
        if MFMessageComposeViewController.canSendText() {
            let composeVC = MFMessageComposeViewController()
            composeVC.messageComposeDelegate = self
            composeVC.recipients = [phoneNumber]
            composeVC.body = message
            
            present(composeVC, animated: true)
        } else {
            let alert = UIAlertController(title: "SMS gönderilemiyor", message: "Bu cihaz SMS göndermeyi desteklemiyor.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Tamam", style: .default))
            present(alert, animated: true)
        }
    }

    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
    }

    @objc func backTapped() {
        // Geri butonunun işlevselliği buraya eklenecek
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}

