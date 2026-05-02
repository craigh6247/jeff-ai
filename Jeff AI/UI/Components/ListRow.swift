import SwiftUI

struct ListRow<Leading: View, Content: View, Trailing: View>: View {
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var content: () -> Content
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            leading()
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

extension ListRow where Leading == EmptyView {
    init(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.leading = { EmptyView() }
        self.content = content
        self.trailing = trailing
    }
}

extension ListRow where Trailing == EmptyView {
    init(
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.leading = leading
        self.content = content
        self.trailing = { EmptyView() }
    }
}
