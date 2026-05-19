//
//  SectionView.swift
//  SwiftUI-Components
//
//  Created by Pham Quang Huy on 2021/01/09.
//

import SwiftUI

struct SectionView<Content: View>: View {
    @State var headerTitle: String?
    @State var footerTitle: String?
    
    let content: () -> Content
    
    var body: some View {
        Group {
            if let _ = self.headerTitle, let _ = self.footerTitle {
                HeaderFooterSectionView
            } else if let _ = self.headerTitle {
                HeaderSectionView
            } else {
                FooterSectionView
            }
        }
    }
    
    private var HeaderFooterSectionView: some View {
        if let headerTitle = self.headerTitle, let footerTitle = self.footerTitle {
            return Section(header: Text(headerTitle), footer: Text(footerTitle)) {
                content()
            }
        }
        
        return Section(header: Text(""), footer: Text("")) {
            content()
        }
    }
    
    private var HeaderSectionView: some View {
        if let headerTitle = headerTitle {
            return Section(header: Text(headerTitle)) {
                content()
            }
        }
        
        return Section(header: Text("")) {
            content()
        }
    }
    
    private var FooterSectionView: some View {
        if let footerTitle = self.footerTitle {
            return Section(footer: Text(footerTitle)) {
                content()
            }
        }
        
        return Section(footer: Text("")) {
            content()
        }
    }
}

struct SectionView_Previews: PreviewProvider {
    static var previews: some View {
        SectionView(headerTitle: "Section", content: { Text("Content") })
            .previewLayout(.sizeThatFits)
    }
}
