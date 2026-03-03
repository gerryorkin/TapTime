//
//  LandmarkPhotoView.swift
//  TapTime
//

import SwiftUI

struct LandmarkPhotoView: View {
    let locationName: String
    let timeZone: TimeZone
    @ObservedObject private var photoService = LandmarkPhotoService.shared

    private var searchInfo: (query: String, slug: String) {
        LandmarkPhotoService.searchInfo(from: locationName, timeZone: timeZone)
    }

    var hasPhoto: Bool {
        photoService.photo(forSlug: searchInfo.slug) != nil
    }

    var body: some View {
        Group {
            if let image = photoService.photo(forSlug: searchInfo.slug) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.3)
            }
        }
        .onAppear {
            let info = searchInfo
            if !info.query.isEmpty {
                photoService.loadPhoto(query: info.query, slug: info.slug)
            }
        }
    }
}
