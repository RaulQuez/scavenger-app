//
//  TaskDetailViewController.swift
//  lab-task-squirrel
//
//  Created by Charlie Hieger on 11/15/22.
//

import UIKit
import MapKit
import PhotosUI
import CoreLocation
import AVFoundation

class TaskDetailViewController: UIViewController {

    // Used to fetch the device's current location when a photo is taken with the camera,
    // since camera captures often lack the embedded GPS metadata that library photos have.
    private let locationManager = CLLocationManager()
    private var pendingCameraLocation: CLLocation?

    @IBOutlet private weak var completedImageView: UIImageView!
    @IBOutlet private weak var completedLabel: UILabel!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var descriptionLabel: UILabel!
    @IBOutlet private weak var attachPhotoButton: UIButton!

    @IBOutlet weak var viewPhoto: UIButton!
    // MapView outlet
    @IBOutlet private weak var mapView: MKMapView!

    var task: Task!

    override func viewDidLoad() {
        super.viewDidLoad()

        // TODO: Register custom annotation view
        mapView.register(
            TaskAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: TaskAnnotationView.identifier
        )
        mapView.delegate = self
        // TODO: Set mapView delegate

        locationManager.delegate = self

        // UI Candy
        mapView.layer.cornerRadius = 12


        updateUI()
        updateMapView()
    }
    
    override func prepare(
        for segue: UIStoryboardSegue,
        sender: Any?
    ) {
        if segue.identifier == "PhotoSegue" {
            if let photoViewController = segue.destination as? PhotoViewController {
                
                photoViewController.task = task
            }
        }
    }

    /// Configure UI for the given task
    private func updateUI() {
        
        viewPhoto.isHidden = !task.isComplete
        
        titleLabel.text = task.title
        descriptionLabel.text = task.description

        let completedImage = UIImage(systemName: task.isComplete ? "circle.inset.filled" : "circle")

        // calling `withRenderingMode(.alwaysTemplate)` on an image allows for coloring the image via it's `tintColor` property.
        completedImageView.image = completedImage?.withRenderingMode(.alwaysTemplate)
        completedLabel.text = task.isComplete ? "Complete" : "Incomplete"

        let color: UIColor = task.isComplete ? .systemBlue : .tertiaryLabel
        completedImageView.tintColor = color
        completedLabel.textColor = color

        mapView.isHidden = !task.isComplete
        attachPhotoButton.isHidden = task.isComplete
    }

    @IBAction func didTapAttachPhotoButton(_ sender: Any) {
        let sourceSheet = UIAlertController(title: "Add Photo", message: nil, preferredStyle: .actionSheet)

        sourceSheet.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
            self?.checkPhotoLibraryAuthorizationAndPresentPicker()
        })

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sourceSheet.addAction(UIAlertAction(title: "Camera", style: .default) { [weak self] _ in
                self?.checkCameraAuthorizationAndPresentCamera()
            })
        }

        sourceSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // Required for iPad: anchor the action sheet to the button that triggered it.
        if let popover = sourceSheet.popoverPresentationController {
            popover.sourceView = sender as? UIView ?? view
        }

        present(sourceSheet, animated: true)
    }

    private func checkPhotoLibraryAuthorizationAndPresentPicker() {
        // TODO: Check and/or request photo library access authorization.
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) != .authorized {

            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in

                switch status {
                case .authorized:
                    DispatchQueue.main.async {
                        self?.presentImagePicker()
                    }
                default:
                    DispatchQueue.main.async {
                        self?.presentGoToSettingsAlert()
                    }
                }
            }
        } else {
            presentImagePicker()
        }
    }

    private func presentImagePicker() {
        // TODO: Create, configure and present image picker.
        var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        
        config.filter = .images
        config.preferredAssetRepresentationMode = .current
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        
        picker.delegate = self
        
        present(picker, animated: true)
    }

    private func checkCameraAuthorizationAndPresentCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.presentCamera()
                    } else {
                        self?.presentGoToSettingsAlert()
                    }
                }
            }
        default:
            presentGoToSettingsAlert()
        }
    }

    private func presentCamera() {
        // Kick off a location request now so it has time to resolve while the user takes the photo.
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }

    func updateMapView() {
        // TODO: Set map viewing region and scale
        guard let imageLocation = task.imageLocation else {
            return
        }
        
        let coordinate = imageLocation.coordinate
        
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(
                latitudeDelta: 0.01, longitudeDelta: 0.01
            )
        )
        
        mapView.setRegion(region, animated: true)
        
        // TODO: Add annotation to map view
        let annotation = MKPointAnnotation()
        
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
    }
}

// TODO: Conform to PHPickerViewControllerDelegate + implement required method(s)

// TODO: Conform to MKMapKitDelegate + implement mapView(_:viewFor:) delegate method.

// Helper methods to present various alerts
extension TaskDetailViewController {

    /// Presents an alert notifying user of photo library access requirement with an option to go to Settings in order to update status.
    func presentGoToSettingsAlert() {
        let alertController = UIAlertController (
            title: "Photo Access Required",
            message: "In order to post a photo to complete a task, we need access to your photo library. You can allow access in Settings",
            preferredStyle: .alert)

        let settingsAction = UIAlertAction(title: "Settings", style: .default) { _ in
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }

            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl)
            }
        }

        alertController.addAction(settingsAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }

    /// Show an alert for the given error
    private func showAlert(for error: Error? = nil) {
        let alertController = UIAlertController(
            title: "Oops...",
            message: "\(error?.localizedDescription ?? "Please try again...")",
            preferredStyle: .alert)

        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)

        present(alertController, animated: true)
    }
}

extension TaskDetailViewController: PHPickerViewControllerDelegate{
    func picker(
        _ picker: PHPickerViewController,
        didFinishPicking results: [PHPickerResult]
    ){
        picker.dismiss(animated: true)
        
        let result = results.first
        
        guard let assetID = result?.assetIdentifier,
              let location = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject?.location else {
            return
        }
        
        print("Image location: \(location.coordinate)")
        
        guard let provider = result?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            
            if let error = error{
                DispatchQueue.main.async {
                    self?.showAlert(for: error)
                }
                return
            }
            guard let image = object as? UIImage else {
                return
            }
            
            DispatchQueue.main.async {
                self?.task.set(image, with: location)
                self?.updateUI()
                self?.updateMapView()
            }
        }
    }
}

extension TaskDetailViewController: MKMapViewDelegate {
    func mapView(
        _ mapView: MKMapView,
        viewFor annotation: MKAnnotation
    ) -> MKAnnotationView? {
        guard let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: TaskAnnotationView.identifier, for: annotation) as? TaskAnnotationView else{
            fatalError("Unusable to dequeue TaskANnotationView")
        }
        
        annotationView.configure(with: task.image)
        
        return annotationView
    }
}

extension TaskDetailViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        pendingCameraLocation = locations.first
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

extension TaskDetailViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage else { return }

        // If CoreLocation hasn't resolved a fix yet, don't fabricate one — ask the user to try again
        // rather than tagging the task with a wrong (0, 0) location.
        guard let location = pendingCameraLocation else {
            let alert = UIAlertController(
                title: "Location Not Ready",
                message: "We couldn't get your location yet. Please try taking the photo again in a moment.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        task.set(image, with: location)
        updateUI()
        updateMapView()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}


