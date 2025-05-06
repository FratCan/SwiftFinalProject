import UIKit
import AVFoundation
import ContactsUI
import MessageUI

class ViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, CNContactPickerDelegate, MFMessageComposeViewControllerDelegate {
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var scannedText: String?
    var selectedPhoneNumber: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        captureSession = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            failed()
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
        setupButtons()
    }
    
    func setupButtons() {
        let selectContactButton = createStyledButton(title: "Kişi Seç", frame: CGRect(x: 20, y: 50, width: 150, height: 50))
        selectContactButton.addTarget(self, action: #selector(selectContactTapped), for: .touchUpInside)
        view.addSubview(selectContactButton)
        
        let backButton = createStyledButton(title: "Geri", frame: CGRect(x: 200, y: 50, width: 100, height: 50), backgroundColor: .systemRed)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)
    }
    
    func createStyledButton(title: String, frame: CGRect, backgroundColor: UIColor = .systemBlue) -> UIButton {
        let button = UIButton(frame: frame)
        button.setTitle(title, for: .normal)
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = 10
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.setTitleColor(.white, for: .normal)
        
        // Click efektleri
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchDragExit, .touchCancel])
        
        return button
    }
    
    @objc func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.alpha = 0.6
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    @objc func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.alpha = 1.0
            sender.transform = .identity
        }
    }

    func failed() {
        let ac = UIAlertController(title: "Hata", message: "Cihazınız QR taramayı desteklemiyor.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Tamam", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                  let stringValue = readableObject.stringValue else { return }
            scannedText = stringValue
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            
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
        }
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
    
    func showConfirmationBeforeSendingSMS() {
        guard let text = scannedText else {
            let alert = UIAlertController(title: "QR Kodu Gerekli", message: "Lütfen önce bir QR kod tarayın.", preferredStyle: .alert)
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
        restartCamera()
    }
    
    func restartCamera() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
