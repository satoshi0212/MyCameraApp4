import UIKit
import UserNotifications

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UNUserNotificationCenterDelegate {

    /// フィルタ名
    static let filterNames: [String] = [
        "フィルタなし",
        "CIPhotoEffectMono",
        "CISepiaTone",
        "CILineOverlay"]

    /// フィルタ選択値
    private var selectedFilterIndex: Int = 0

    /// 加工前画像
    private var originalImage: UIImage?

    /// 処理中インジケータ
    private let indicator = UIActivityIndicatorView()

    @IBOutlet weak var imageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // imageView上の操作を有効化
        self.imageView.isUserInteractionEnabled = true

        // 処理中インジケータの初期化
        self.indicator.activityIndicatorViewStyle = .whiteLarge
        self.indicator.center = self.view.center
        self.indicator.hidesWhenStopped = true
        self.view.addSubview(indicator)

        // 通知許可の取得と初期化
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.badge, .sound, .alert]) { granted, error in
            if error != nil { return }
            if granted {
                center.delegate = self
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @IBAction func didTouchCameraButton(_ sender: Any) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            print("カメラへのアクセスができません")
            return
        }
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .camera
        self.present(imagePickerController, animated: true)
    }

    @IBAction func didTouchShareButton(_ sender: Any) {
        guard let image = imageView.image else {
            print("撮影した写真が設定されていません")
            return
        }
        let shareText = "#MyCameraApp"
        // シェア用にサイズ変換
        let resized = image.resizedImage(size: imageView.frame.size)
        let activityItems: [Any] = [shareText, resized]
        let activityController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        activityController.popoverPresentationController?.sourceView = imageView
        self.present(activityController, animated: true)
    }

    @IBAction func didTouchMakeNotificationButton(_ sender: Any) {
        let content = UNMutableNotificationContent()
        content.title = "Title"
        content.subtitle = "Subtitle"
        content.body = "Body"
        content.sound = UNNotificationSound.default()

        if let image = imageView.image,
            let attachment = UNNotificationAttachment.create(image: image) {
            content.attachments = [attachment]
        }

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "my_interval",
                                            content: content,
                                            trigger: trigger)

        UNUserNotificationCenter.current().add(
            request, withCompletionHandler: nil)

        let alert = UIAlertController(title: "通知登録", message: "登録しました", preferredStyle: .alert)
        let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(defaultAction)
        self.present(alert, animated: true, completion: nil)
    }

    @IBAction func didTouchClearNotificationButton(_ sender: Any) {
        let center = UNUserNotificationCenter.current()

        center.removePendingNotificationRequests(
            withIdentifiers: ["my_interval"])
        center.removeDeliveredNotifications(
            withIdentifiers: ["my_interval"])

        let alert = UIAlertController(title: "通知解除", message: "解除しました", preferredStyle: .alert)
        let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(defaultAction)
        self.present(alert, animated: true, completion: nil)
    }

    @IBAction func swipeRight(_ sender: Any) {
        // 画像がなかったら処理を抜ける
        guard let image = self.originalImage else { return }

        // 先頭のフィルタを選択していたら処理を抜ける
        guard self.selectedFilterIndex > 0 else { return }

        // 1つ前のフィルタを選択
        self.selectedFilterIndex -= 1

        // フィルタ処理実行
        let names = ViewController.filterNames
        let name = names[self.selectedFilterIndex]
        self.doFilter(image: image, filterName: name)
    }

    @IBAction func swipeLeft(_ sender: Any) {
        // 画像がなかったら処理を抜ける
        guard let image = self.originalImage else { return }

        // 末尾のフィルタを選択していたら処理を抜ける
        let names = ViewController.filterNames
        guard self.selectedFilterIndex < names.count - 1 else { return }

        // 次のフィルタを選択
        self.selectedFilterIndex += 1

        // フィルタ処理実行
        let name = names[self.selectedFilterIndex]
        self.doFilter(image: image, filterName: name)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            let fixedImage = image.correctlyOrientedImage()
            self.originalImage = fixedImage
            self.imageView.image = fixedImage
            UIImageWriteToSavedPhotosAlbum(fixedImage, nil, nil, nil)
        }
        picker.dismiss(animated: true)
    }

    private func doFilter(image: UIImage, filterName: String) {
        self.view.isUserInteractionEnabled = false
        self.indicator.startAnimating()

        DispatchQueue.global().async {
            let outputImage: UIImage
            if filterName != "フィルタなし" {
                let ciImage = CIImage(image: image)
                let filter = CIFilter(name: filterName)!
                filter.setValue(ciImage, forKey: kCIInputImageKey)

                let ciContext = CIContext(options: nil)
                let imageRef = ciContext.createCGImage((filter.outputImage)!, from: (filter.outputImage?.extent)!)
                outputImage = UIImage(cgImage: imageRef!, scale: image.scale, orientation: image.imageOrientation)
            } else {
                outputImage = image
            }

            DispatchQueue.main.sync {
                self.view.isUserInteractionEnabled = true
                self.indicator.stopAnimating()
                self.imageView.image = outputImage
            }
        }
    }
}

extension UNNotificationAttachment {
    static func create(
        image: UIImage) -> UNNotificationAttachment? {

        // 画像サイズが大きすぎると
        // 通知に添付できないためサイズ変換
        let size = CGSize(width: 120, height: 120)
        let resized = image.resizedImage(size: size)

        // UIImageからデータ型に変換
        let data = UIImagePNGRepresentation(resized)!

        // 一時保存ディレクトリ名作成
        let uuid = UUID().uuidString
        let dirURL = URL(fileURLWithPath:
            NSTemporaryDirectory())
            .appendingPathComponent(uuid)

        let fm = FileManager.default

        // 一時保存ディレクトリ生成
        try! fm.createDirectory(
            at: dirURL,
            withIntermediateDirectories: true,
            attributes: nil)

        // 一時保存ファイル生成
        let fileURL = dirURL
            .appendingPathComponent("mycamera.png")
        try! data.write(to: fileURL)

        // 通知添付情報生成
        let attachment =
            try! UNNotificationAttachment(
                identifier: "mycamera.png",
                url: fileURL, options: nil)

        return attachment
    }
}

extension UIImage {
    func correctlyOrientedImage() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }

    func resizedImage(size _size: CGSize) -> UIImage {
        // アスペクト比を考慮し、変更後のサイズを計算する
        let wRatio = _size.width / size.width
        let hRatio = _size.height / size.height
        let ratio = wRatio < hRatio ? wRatio : hRatio
        let resized = CGSize(
            width: size.width * ratio,
            height: size.height * ratio
        )
        // サイズ変更
        UIGraphicsBeginImageContextWithOptions(resized, false, self.scale)
        draw(in: CGRect(origin: .zero, size: resized))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return resizedImage
    }
}
