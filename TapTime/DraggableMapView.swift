//
//  DraggableMapView.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI
import MapKit

// Custom annotation class for draggable pins
class DraggableAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    let id: UUID
    let title: String?
    let subtitle: String?
    let isLocked: Bool
    
    init(id: UUID, coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, isLocked: Bool) {
        self.id = id
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.isLocked = isLocked
        super.init()
    }
}

struct DraggableMapView: UIViewRepresentable {
    @ObservedObject var locationManager: LocationManager
    @Binding var cameraPosition: MKCoordinateRegion
    @Binding var isMapScrolling: Bool
    let onTap: (CLLocationCoordinate2D) -> Void
    let showTimezoneLines: Bool
    let showCountryLabels: Bool
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = false

        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        // Add pan gesture to track user scrolling
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(panGesture)

        // Add pinch gesture to track user zooming
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        pinchGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(pinchGesture)

        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region if needed, but only if it's a significant change to avoid feedback loops
        let currentRegion = mapView.region
        let threshold = 0.0001 // Minimum difference to trigger update
        
        if abs(currentRegion.center.latitude - cameraPosition.center.latitude) > threshold ||
           abs(currentRegion.center.longitude - cameraPosition.center.longitude) > threshold ||
           abs(currentRegion.span.latitudeDelta - cameraPosition.span.latitudeDelta) > threshold ||
           abs(currentRegion.span.longitudeDelta - cameraPosition.span.longitudeDelta) > threshold {
            context.coordinator.shouldUpdateBinding = false // Prevent feedback
            mapView.setRegion(cameraPosition, animated: true)
        }
        
        // Update annotations to show red dots
        context.coordinator.updateAnnotations(on: mapView, with: locationManager.savedLocations)
        
        // Update timezone overlays
        context.coordinator.updateTimezoneOverlays(on: mapView, show: showTimezoneLines)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: DraggableMapView
        private var currentAnnotations: [UUID: DraggableAnnotation] = [:]
        private var timezoneOverlays: [MKPolyline] = []
        var shouldUpdateBinding = true
        private var scrollEndTask: Task<Void, Never>?

        init(_ parent: DraggableMapView) {
            self.parent = parent
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                scrollEndTask?.cancel()
                parent.isMapScrolling = true
            case .ended, .cancelled:
                scheduleScrollEnd()
            default:
                break
            }
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                scrollEndTask?.cancel()
                parent.isMapScrolling = true
            case .ended, .cancelled:
                scheduleScrollEnd()
            default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        private func scheduleScrollEnd() {
            scrollEndTask?.cancel()
            scrollEndTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                parent.isMapScrolling = false
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Also schedule scroll end here to catch momentum scrolling
            if parent.isMapScrolling {
                scheduleScrollEnd()
            }
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onTap(coordinate)
        }
        
        func updateAnnotations(on mapView: MKMapView, with locations: [SavedLocation]) {
            // Remove annotations that no longer exist
            let currentIDs = Set(locations.map { $0.id })
            let annotationsToRemove = currentAnnotations.values.filter { !currentIDs.contains($0.id) }
            mapView.removeAnnotations(Array(annotationsToRemove))
            annotationsToRemove.forEach { currentAnnotations.removeValue(forKey: $0.id) }
            
            // Add or update annotations
            for location in locations {
                if let existingAnnotation = currentAnnotations[location.id] {
                    // Update coordinate if changed
                    if existingAnnotation.coordinate.latitude != location.coordinate.latitude ||
                       existingAnnotation.coordinate.longitude != location.coordinate.longitude {
                        existingAnnotation.coordinate = location.coordinate
                    }
                    // If lock status changed, we need to recreate the annotation view
                    if existingAnnotation.isLocked != location.isLocked {
                        mapView.removeAnnotation(existingAnnotation)
                        currentAnnotations.removeValue(forKey: location.id)
                        let newAnnotation = DraggableAnnotation(
                            id: location.id,
                            coordinate: location.coordinate,
                            title: location.locationName,
                            subtitle: location.timeZone.identifier,
                            isLocked: location.isLocked
                        )
                        currentAnnotations[location.id] = newAnnotation
                        mapView.addAnnotation(newAnnotation)
                    }
                } else {
                    // Create new annotation
                    let annotation = DraggableAnnotation(
                        id: location.id,
                        coordinate: location.coordinate,
                        title: location.locationName,
                        subtitle: location.timeZone.identifier,
                        isLocked: location.isLocked
                    )
                    currentAnnotations[location.id] = annotation
                    mapView.addAnnotation(annotation)
                }
            }
        }
        
        func updateTimezoneOverlays(on mapView: MKMapView, show: Bool) {
            if show && timezoneOverlays.isEmpty {
                // Add timezone lines
                for offset in -12..<13 {
                    let longitude = Double(offset) * 15.0
                    let coordinates = [
                        CLLocationCoordinate2D(latitude: -90, longitude: longitude),
                        CLLocationCoordinate2D(latitude: 90, longitude: longitude)
                    ]
                    let polyline = MKPolyline(coordinates: coordinates, count: 2)
                    timezoneOverlays.append(polyline)
                    mapView.addOverlay(polyline)
                }
            } else if !show && !timezoneOverlays.isEmpty {
                // Remove timezone lines
                mapView.removeOverlays(timezoneOverlays)
                timezoneOverlays.removeAll()
            }
        }
        
        // MARK: - MKMapViewDelegate
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Don't customize user location
            if annotation is MKUserLocation {
                return nil
            }
            
            guard let draggableAnnotation = annotation as? DraggableAnnotation else {
                return nil
            }
            
            let identifier = "DraggablePin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false // No popup
                annotationView?.isDraggable = false // Not draggable anymore
                annotationView?.animatesWhenAdded = false // Don't animate when added
            } else {
                annotationView?.annotation = annotation
            }
            
            // Color based on lock status: green if locked, red if unlocked
            annotationView?.markerTintColor = draggableAnnotation.isLocked ? .systemGreen : .systemRed
            
            // Add lock icon for locked locations
            if draggableAnnotation.isLocked {
                // Create a lock icon for locked pins
                let lockConfig = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
                annotationView?.glyphImage = UIImage(systemName: "lock.fill", withConfiguration: lockConfig)
                annotationView?.glyphTintColor = .white
            } else {
                annotationView?.glyphImage = nil
            }
            
            annotationView?.displayPriority = .required // Keep size consistent
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            // Immediately deselect so pins never stay enlarged
            mapView.deselectAnnotation(annotation, animated: false)
        }

        // Remove the old delete button handler
        @objc func deleteButtonTapped(_ sender: UIButton) {
            // No longer needed
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.blue.withAlphaComponent(0.3)
                renderer.lineWidth = 1
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            // Only update binding if the change originated from user interaction
            guard shouldUpdateBinding else {
                shouldUpdateBinding = true // Reset flag
                return
            }
            
            // Use a transaction to prevent triggering view updates
            Task { @MainActor in
                parent.cameraPosition = mapView.region
            }
        }
    }
}
