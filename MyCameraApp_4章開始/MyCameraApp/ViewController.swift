import UIKit

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @IBOutlet weak var imageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
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

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            imageView.image = image
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
        picker.dismiss(animated: true)
    }
}

extension UIImage {
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
        UIGraphicsBeginImageContextWithOptions(resized, false, scale)
        draw(in: CGRect(origin: .zero, size: resized))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return resizedImage
    }
}
