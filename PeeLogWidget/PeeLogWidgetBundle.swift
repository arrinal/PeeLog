//
//  PeeLogWidgetBundle.swift
//  PeeLogWidget
//
//  Created by Arrinal S on 08/10/25.
//

import WidgetKit
import SwiftUI

@main
struct PeeLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Expose the Quick Log widget implemented in
        // PeeLog/Presentation/Widgets/QuickLogWidget.swift
        QuickLogWidget()
    }
}
