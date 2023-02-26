import Foundation
import Vision

// typealias for the action classifier model
typealias actionClassifier = FallingDetection_1

// A protocol for communicating the results of the pose estimation and action classification
protocol PredictorDelegate: AnyObject {
    // Called when new recognized points are detected
    func predictor(_ predictor: Predictor, didFindnewRecognizedPoints points: [CGPoint])
    // Called when an action is detected
    func predictor(_ predictor: Predictor, didLabelAction action: String, with confidence: Double)
}

// The predictor class, responsible for pose estimation and action classification
class Predictor {
    // The delegate object that will receive the results
    weak var delegate: PredictorDelegate?
    // The number of frames to keep in the pose window
    let predictionWindowSize = 60
    // The buffer to store the past frames' pose observations
    var posesWindow: [VNHumanBodyPoseObservation] = []
    
    // The initializer for the predictor
    init() {
        // Reserve capacity for the pose window buffer
        posesWindow.reserveCapacity(predictionWindowSize)
    }
    
    // The function to estimate poses from a video frame
    func estimation(sampleBuffer: CMSampleBuffer) {
        // Create a VNImageRequestHandler to handle the sample buffer
        let requestHandler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer,
                                                   orientation: .up)
        // Create a VNDetectHumanBodyPoseRequest to detect poses
        let request = VNDetectHumanBodyPoseRequest(completionHandler: bodyPoseHandler)
        do {
            // Perform the request on the image
            try requestHandler.perform([request])
        } catch {
            print("Unable to perform the request, with error: \(error)")
        }
    }
    
    // The handler function to process the pose observation results
    func bodyPoseHandler(request: VNRequest, error: Error?) {
        // Check if the request produced any observations
        guard let observations = request.results as? [VNHumanBodyPoseObservation] else { return }
        
        // Process each observation
        observations.forEach {
            processObservation($0)
        }
        
        // If there is at least one observation, store it and label the action type
        if let result = observations.first {
            storeObservation(result)
            labelActionType()
        }
    }
    
    // The function to label the action type
    func labelActionType() {
        // Create a new actionClassifier instance
        guard let actionClassifier = try? actionClassifier(configuration: MLModelConfiguration()),
        // Prepare the input with the current poses window
        let poseMultiArray = prepareInputWithObservations(posesWindow),
        // Get the predictions from the actionClassifier model
        let predictions = try? actionClassifier.prediction(poses: poseMultiArray) else {
            return
        }
        
        // Extract the predicted label and confidence level
        let label = predictions.label
        let confidence = predictions.labelProbabilities[label] ?? 0
        
        // Inform the delegate of the detected action
        delegate?.predictor(self, didLabelAction: label, with: confidence)
    }
    
    // This function takes an array of VNHumanBodyPoseObservation objects and prepares them as input for the machine learning model.
    func prepareInputWithObservations(_ observations: [VNHumanBodyPoseObservation]) -> MLMultiArray? {
        
        // The number of available frames is determined by the size of the input array.
        let numAvailableFrames = observations.count
        
        // The number of observations needed for the input is set to 60.
        let observationsNeeded = 60
        
        // An empty array of MLMultiArray objects is created to store the individual frames of the observations.
        var multiArrayBuffer = [MLMultiArray]()
        
        // A loop is run over each frame in the available observations, with a limit of either 60 or the total number of available frames.
        for frameIndex in 0 ..< min(numAvailableFrames, observationsNeeded) {
            
            // The individual frame of the observation is extracted.
            let pose = observations[frameIndex]
            
            // The keypointsMultiArray function is called on the individual frame to obtain an MLMultiArray object.
            do {
                let oneFrameMultiArray = try pose.keypointsMultiArray()
                // The MLMultiArray object is appended to the multiArrayBuffer.
                multiArrayBuffer.append(oneFrameMultiArray)
            } catch {
                // If there is an error obtaining the MLMultiArray object, the loop moves on to the next frame.
                continue
            }
        }
        
        // If there are less than 60 available frames, the loop runs over the remaining number of frames to create empty MLMultiArray objects.
        if numAvailableFrames < observationsNeeded {
            for _ in 0 ..< (observationsNeeded - numAvailableFrames) {
                do {
                    let oneFrameMultiArray = try MLMultiArray(shape: [1, 3, 18], dataType: .double)
                    // The resetMultiArray function is called on the newly created MLMultiArray object to fill it with zeroes.
                    try resetMultiArray(oneFrameMultiArray)
                    // The MLMultiArray object is appended to the multiArrayBuffer.
                    multiArrayBuffer.append(oneFrameMultiArray)
                } catch {
                    // If there is an error creating or resetting the MLMultiArray object, the loop moves on to the next frame.
                    continue
                }
            }
        }
        
        // The MLMultiArray objects in the multiArrayBuffer are concatenated along the first axis to form a single MLMultiArray object for the entire sequence of observations.
        return MLMultiArray(concatenating: [MLMultiArray](multiArrayBuffer), axis: 0, dataType: .double)
    }
    
    func resetMultiArray(_ predictionWindow: MLMultiArray, with value: Double = 0.0) throws {
        let pointer = try UnsafeMutableBufferPointer<Double>(predictionWindow)
        pointer.initialize(repeating: value)
    }
    
    // This function stores a VNHumanBodyPoseObservation object in a queue of size predictionWindowSize.
    func storeObservation(_ observation: VNHumanBodyPoseObservation) {
        // If the queue is already at maximum size, the oldest observation is removed.
        if posesWindow.count >=  predictionWindowSize {
            posesWindow.removeFirst()
        }
        // The new observation is appended to the end of the queue.
        posesWindow.append(observation)
    }
    
    // This function processes a VNHumanBodyPoseObservation by extracting the recognizedPoints and converting them to displayedPoints.
    func processObservation(_ observation: VNHumanBodyPoseObservation) {
        do {
            // Extract recognized points from the observation for all body groups.
            let recognizedPoints = try observation.recognizedPoints(forGroupKey: .all)
            
            // Map the recognized points to displayed points by converting the x and y values and adjusting for screen orientation.
            let displayedPoints = recognizedPoints.map {
                CGPoint(x: $0.value.x, y: 1 - $0.value.y)
            }
            
            // Notify the delegate of the new recognized points.
            delegate?.predictor(self, didFindnewRecognizedPoints: displayedPoints)
        } catch {
            // If there was an error extracting recognized points, print an error message.
            print("Error finding recognizedPoints")
        }
    }
}
