import UIKit
import AVFoundation
import AudioToolbox

class ViewController: UIViewController {
    
    // Initialize a VideoCapture instance
    let videoCapture = VideoCapture()
    
    // A preview layer to display the video captured by the VideoCapture instance
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    // A layer to draw dots for the recognized joint points
    var pointsLayer = CAShapeLayer()
    
    // A boolean variable to keep track of whether a fall has been detected
    var isFallDetected = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the video preview layer and the points layer
        setupVideoPreview()
        
        // Set the delegate of the predictor object to this view controller
        videoCapture.predictor.delegate = self
        
        // Disable the automatic screen locking feature
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    // Set up the video preview layer and the points layer
    private func setupVideoPreview() {
        
        // Start the video capture session
        videoCapture.startCaptureSession()
        
        // Create a preview layer using the capture session of the VideoCapture instance
        previewLayer = AVCaptureVideoPreviewLayer(session: videoCapture.captureSession)
        
        // Make sure the preview layer is not nil before adding it to the view's layer
        guard let previewLayer = previewLayer else { return }
        
        // Add the preview layer to the view's layer and set its frame to fill the entire screen
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.frame
        
        // Add the points layer to the view's layer and set its frame to fill the entire screen
        view.layer.addSublayer(pointsLayer)
        pointsLayer.frame = view.frame
        
        // Set the color of the dots drawn by the points layer to blue
        pointsLayer.strokeColor = UIColor.blue.cgColor
    }
}

// Conform to the PredictorDelegate protocol to receive predictions and recognized joint points
extension ViewController: PredictorDelegate {
    
    // This function is called when the predictor object makes a prediction with high confidence that the user has fallen
    func predictor(_ predictor: Predictor, didLabelAction action: String, with confidence: Double) {
        
        // Print the confidence level of the prediction to the console
        print(confidence)
        
        // Check if the predicted action is "Falling", the confidence is higher than 0.97, and a fall has not already been detected
        if action == "Falling" && confidence > 0.97 && isFallDetected == false {
            
            // Set the isFallDetected variable to true
            isFallDetected = true
            
            // Reset the isFallDetected variable to false after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.isFallDetected = false
            }
            
            // Play an alert sound to notify the user of the fall
            DispatchQueue.main.async {
                AudioServicesPlayAlertSound(SystemSoundID(1322))
            }
        }
    }
    
    // This function is called when the predictor finds new recognized points
    // The function takes in a predictor object and an array of CGPoint objects representing the points that have been recognized

    func predictor(_ predictor: Predictor, didFindnewRecognizedPoints points: [CGPoint]) {
        // If there is no preview layer available, exit the function
        guard let previewLayer = previewLayer else { return }

        // Convert the recognized points to points in the preview layer's coordinate system
        let convertedPoints = points.map {
            previewLayer.layerPointConverted(fromCaptureDevicePoint: $0)
        }

        // Create a new combined path for all the points
        let combinedPath = CGMutablePath()

        // Loop through each point and create a small circle (a dot) centered on that point
        for point in convertedPoints {
            let dotPath = UIBezierPath(ovalIn: CGRect(x: point.x, y: point.y, width: 10, height: 10))
            
            // Add the dot to the combined path
            combinedPath.addPath(dotPath.cgPath)
        }

        // Set the path of the points layer to the combined path
        pointsLayer.path = combinedPath

        // Trigger a value change for the points layer on the main thread
        DispatchQueue.main.async {
            self.pointsLayer.didChangeValue(for: \.path)
        }
    }
}
