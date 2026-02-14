//
//  MapTapHandler.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import SwiftUI
import MapKit

struct MapTapReader: UIViewRepresentable {
    let onTap: (CLLocationCoordinate2D) -> Void
    @Binding var cameraPosition: MapCameraPosition
    
    func makeUIView(context: Context) -> MapTapView {
        let view = MapTapView()
        view.onTap = onTap
        return view
    }
    
    func updateUIView(_ uiView: MapTapView, context: Context) {
        uiView.onTap = onTap
    }
}

class MapTapView: UIView {
    var onTap: ((CLLocationCoordinate2D) -> Void)?
    private var mapView: MKMapView?
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if let mapView = findMapView(in: superview) {
            self.mapView = mapView
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            mapView.addGestureRecognizer(tapGesture)
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let mapView = mapView else { return }
        
        let point = gesture.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        onTap?(coordinate)
    }
    
    private func findMapView(in view: UIView?) -> MKMapView? {
        guard let view = view else { return nil }
        
        if let mapView = view as? MKMapView {
            return mapView
        }
        
        for subview in view.subviews {
            if let mapView = findMapView(in: subview) {
                return mapView
            }
        }
        
        return nil
    }
}
