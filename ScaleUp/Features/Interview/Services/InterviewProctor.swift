import Foundation
import AVFoundation
import Vision
import UIKit

@Observable @MainActor
final class InterviewProctor {
    var cameraEnabled = false
    var gazeAlerts: [(timestamp: Double, type: String)] = []
    var currentStatus: ProctorStatus = .ready
    var snapshotData: [(s3Key: String, timestamp: Double)] = []

    enum ProctorStatus: Equatable {
        case ready, monitoring, alert(String), disabled
    }

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var snapshotTimer: Timer?
    private var lastFaceDetectedTime = Date()
    private var interviewStartTime = Date()
    private let interviewService = InterviewService()
    private var sessionId: String = ""

    // MARK: - Start Monitoring

    func startMonitoring(sessionId: String, startTime: Date) {
        self.sessionId = sessionId
        self.interviewStartTime = startTime

        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            currentStatus = .disabled
            return
        }

        setupCamera()
        cameraEnabled = true
        currentStatus = .monitoring

        snapshotTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.captureAndUploadSnapshot()
            }
        }
    }

    // MARK: - Stop Monitoring

    func stopMonitoring() {
        captureSession?.stopRunning()
        snapshotTimer?.invalidate()
        currentStatus = .ready
        cameraEnabled = false
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .low

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {
            currentStatus = .disabled
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(
            ProctorBufferDelegate(proctor: self),
            queue: DispatchQueue(label: "com.scaleup.proctoring")
        )
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        captureSession = session
        videoOutput = output

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    // MARK: - Frame Analysis

    func handleFaceDetectionResult(faceCount: Int) {
        let elapsed = Date().timeIntervalSince(interviewStartTime)

        if faceCount == 0 {
            let timeSinceLastFace = Date().timeIntervalSince(lastFaceDetectedTime)
            if timeSinceLastFace > 5 {
                gazeAlerts.append((timestamp: elapsed, type: "face_not_found"))
                currentStatus = .alert("Face not detected")
            }
        } else if faceCount > 1 {
            gazeAlerts.append((timestamp: elapsed, type: "multiple_faces"))
            currentStatus = .alert("Multiple faces detected")
        } else {
            lastFaceDetectedTime = Date()
            currentStatus = .monitoring
        }
    }

    // MARK: - Snapshot

    private func captureAndUploadSnapshot() {
        let elapsed = Date().timeIntervalSince(interviewStartTime)
        snapshotData.append((s3Key: "interviews/\(sessionId)/snap_\(Int(elapsed)).jpg", timestamp: elapsed))
    }

    // MARK: - Integrity Data

    var integrityData: [String: Any] {
        [
            "cameraEnabled": cameraEnabled,
            "gazeAlerts": gazeAlerts.map { ["timestamp": $0.timestamp, "type": $0.type] },
            "snapshotCount": snapshotData.count,
        ]
    }

    // MARK: - Capture Session Accessor (for camera preview)

    var activeCaptureSession: AVCaptureSession? { captureSession }
}

// MARK: - Buffer Delegate

class ProctorBufferDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated(unsafe) weak var proctor: InterviewProctor?
    private var frameCount = 0

    init(proctor: InterviewProctor) {
        self.proctor = proctor
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCount += 1
        guard frameCount % 30 == 0 else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Perform Vision analysis on the proctoring queue, then dispatch results
        let proctor = self.proctor
        let request = VNDetectFaceRectanglesRequest { request, _ in
            let count = (request.results as? [VNFaceObservation])?.count ?? 0
            Task { @MainActor in
                proctor?.handleFaceDetectionResult(faceCount: count)
            }
        }
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored).perform([request])
    }
}
