import Contacts
import Foundation
import MapKit

extension MKMapItem {
    var formattedAddress: String {
        if let postalAddress = placemark.postalAddress {
            let formatter = CNPostalAddressFormatter()
            let formatted = formatter.string(from: postalAddress)
            return formatted.replacingOccurrences(of: "\n", with: ", ")
        }

        return placemark.title ?? L10n.addressUnavailable
    }
}
