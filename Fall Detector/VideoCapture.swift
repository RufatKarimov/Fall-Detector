import Foundation
import AVFoundation

class VideoCapture: NSObject {
    // Initialize AVCaptureSession and AVCaptureVideoDataOutput objects
    let captureSession = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    
    // Initialize Predictor object
    let predictor = Predictor()
    
    // Override the init() method to set up AVCaptureSession and AVCaptureDeviceInput
    override init() {
        super.init()
        // Get the default video capture device and create an AVCaptureDeviceInput object from it
        guard let captureDevice = AVCaptureDevice.default(for: .video),
                let input = try? AVCaptureDeviceInput(device: captureDevice) else {
            return
        }
        
        // Set the capture session preset to high and add the input to the session
        captureSession.sessionPreset = AVCaptureSession.Preset.high
        captureSession.addInput(input)
        
        // Add the video output to the session and set its alwaysDiscardsLateVideoFrames property to true
        captureSession.addOutput(videoOutput)
        videoOutput.alwaysDiscardsLateVideoFrames = true
    }
    
    // Start the capture session and set the sample buffer delegate
    func startCaptureSession() {
        captureSession.startRunning()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoDispatchQueue"))
    }
}

// Extend the VideoCapture class to conform to the AVCaptureVideoDataOutputSampleBufferDelegate protocol
extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    // Implement the captureOutput method to pass the sample buffer to the predictor
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        predictor.estimation(sampleBuffer: sampleBuffer)
    }
}
