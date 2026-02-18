//
//  CountryLabels.swift
//  TapTime
//
//  Created by Gerry Orkin on 13/2/2026.
//

import MapKit

struct CountryLabel: Hashable {
    let name: String
    let coordinate: CLLocationCoordinate2D

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    static func == (lhs: CountryLabel, rhs: CountryLabel) -> Bool {
        lhs.name == rhs.name
    }
}

// Major countries with approximate center coordinates
let majorCountries: [CountryLabel] = [
    CountryLabel(name: "USA", coordinate: CLLocationCoordinate2D(latitude: 39.8, longitude: -98.5)),
    CountryLabel(name: "Canada", coordinate: CLLocationCoordinate2D(latitude: 56.1, longitude: -106.3)),
    CountryLabel(name: "Mexico", coordinate: CLLocationCoordinate2D(latitude: 23.6, longitude: -102.5)),
    CountryLabel(name: "Brazil", coordinate: CLLocationCoordinate2D(latitude: -14.2, longitude: -51.9)),
    CountryLabel(name: "Argentina", coordinate: CLLocationCoordinate2D(latitude: -38.4, longitude: -63.6)),
    CountryLabel(name: "UK", coordinate: CLLocationCoordinate2D(latitude: 55.3, longitude: -3.4)),
    CountryLabel(name: "France", coordinate: CLLocationCoordinate2D(latitude: 46.2, longitude: 2.2)),
    CountryLabel(name: "Germany", coordinate: CLLocationCoordinate2D(latitude: 51.1, longitude: 10.4)),
    CountryLabel(name: "Spain", coordinate: CLLocationCoordinate2D(latitude: 40.4, longitude: -3.7)),
    CountryLabel(name: "Italy", coordinate: CLLocationCoordinate2D(latitude: 41.8, longitude: 12.5)),
    CountryLabel(name: "Russia", coordinate: CLLocationCoordinate2D(latitude: 61.5, longitude: 105.3)),
    CountryLabel(name: "China", coordinate: CLLocationCoordinate2D(latitude: 35.8, longitude: 104.1)),
    CountryLabel(name: "India", coordinate: CLLocationCoordinate2D(latitude: 20.5, longitude: 78.9)),
    CountryLabel(name: "Japan", coordinate: CLLocationCoordinate2D(latitude: 36.2, longitude: 138.2)),
    CountryLabel(name: "Australia", coordinate: CLLocationCoordinate2D(latitude: -25.2, longitude: 133.7)),
    CountryLabel(name: "South Africa", coordinate: CLLocationCoordinate2D(latitude: -30.5, longitude: 22.9)),
    CountryLabel(name: "Egypt", coordinate: CLLocationCoordinate2D(latitude: 26.8, longitude: 30.8)),
    CountryLabel(name: "Saudi Arabia", coordinate: CLLocationCoordinate2D(latitude: 23.8, longitude: 45.0)),
    CountryLabel(name: "Turkey", coordinate: CLLocationCoordinate2D(latitude: 38.9, longitude: 35.2)),
    CountryLabel(name: "Indonesia", coordinate: CLLocationCoordinate2D(latitude: -0.7, longitude: 113.9)),
    CountryLabel(name: "Thailand", coordinate: CLLocationCoordinate2D(latitude: 15.8, longitude: 100.9)),
    CountryLabel(name: "South Korea", coordinate: CLLocationCoordinate2D(latitude: 35.9, longitude: 127.7)),
    CountryLabel(name: "New Zealand", coordinate: CLLocationCoordinate2D(latitude: -40.9, longitude: 174.8)),
    CountryLabel(name: "Chile", coordinate: CLLocationCoordinate2D(latitude: -35.6, longitude: -71.5)),
    CountryLabel(name: "Peru", coordinate: CLLocationCoordinate2D(latitude: -9.1, longitude: -75.0)),
    CountryLabel(name: "Colombia", coordinate: CLLocationCoordinate2D(latitude: 4.5, longitude: -74.2)),
    CountryLabel(name: "Nigeria", coordinate: CLLocationCoordinate2D(latitude: 9.0, longitude: 8.6)),
    CountryLabel(name: "Kenya", coordinate: CLLocationCoordinate2D(latitude: -0.0, longitude: 37.9)),
    CountryLabel(name: "Norway", coordinate: CLLocationCoordinate2D(latitude: 60.4, longitude: 8.4)),
    CountryLabel(name: "Sweden", coordinate: CLLocationCoordinate2D(latitude: 60.1, longitude: 18.6)),
    CountryLabel(name: "Poland", coordinate: CLLocationCoordinate2D(latitude: 51.9, longitude: 19.1)),
    CountryLabel(name: "Ukraine", coordinate: CLLocationCoordinate2D(latitude: 48.3, longitude: 31.1)),
    CountryLabel(name: "Iran", coordinate: CLLocationCoordinate2D(latitude: 32.4, longitude: 53.6)),
    CountryLabel(name: "Pakistan", coordinate: CLLocationCoordinate2D(latitude: 30.3, longitude: 69.3)),
    CountryLabel(name: "Vietnam", coordinate: CLLocationCoordinate2D(latitude: 14.0, longitude: 108.2)),
    CountryLabel(name: "Philippines", coordinate: CLLocationCoordinate2D(latitude: 12.8, longitude: 121.7)),
    CountryLabel(name: "Malaysia", coordinate: CLLocationCoordinate2D(latitude: 4.2, longitude: 101.9)),
    CountryLabel(name: "Afghanistan", coordinate: CLLocationCoordinate2D(latitude: 33.9, longitude: 67.7)),
    CountryLabel(name: "Morocco", coordinate: CLLocationCoordinate2D(latitude: 31.7, longitude: -7.0)),
    CountryLabel(name: "Algeria", coordinate: CLLocationCoordinate2D(latitude: 28.0, longitude: 1.6)),
]
