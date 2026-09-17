import SwiftUI
import GoogleMobileAds

/// AdMob GADNativeAdView representing the Media, Body, CTA button, and AdChoices
final class NativeAdMediaContainerUIView: UIView {
    let nativeAdView = GADNativeAdView()
    let mediaView = GADMediaView()
    let bodyLabel = UILabel()
    let callToActionButton = UIButton(type: .custom)
    let ctaLabel = UILabel()
    let contentStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayout()
    }

    private func setupLayout() {
        backgroundColor = .clear
        addSubview(nativeAdView)
        nativeAdView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            nativeAdView.topAnchor.constraint(equalTo: topAnchor),
            nativeAdView.leadingAnchor.constraint(equalTo: leadingAnchor),
            nativeAdView.trailingAnchor.constraint(equalTo: trailingAnchor),
            nativeAdView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Media View (Video / Image)
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.clipsToBounds = true
        mediaView.layer.cornerRadius = 10
        mediaView.backgroundColor = UIColor.secondarySystemBackground

        // Body Label (with proper line height and no truncation)
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .systemFont(ofSize: 13, weight: .regular)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 2
        bodyLabel.lineBreakMode = .byTruncatingTail

        // CTA Button (Full-width custom label inside)
        callToActionButton.translatesAutoresizingMaskIntoConstraints = false
        callToActionButton.backgroundColor = UIColor.systemBlue
        callToActionButton.layer.cornerRadius = 10
        callToActionButton.clipsToBounds = true
        callToActionButton.isUserInteractionEnabled = false // GADNativeAdView handles tap on CTA button

        ctaLabel.translatesAutoresizingMaskIntoConstraints = false
        ctaLabel.font = .systemFont(ofSize: 14, weight: .bold)
        ctaLabel.textColor = .white
        ctaLabel.textAlignment = .center
        ctaLabel.adjustsFontSizeToFitWidth = true
        ctaLabel.minimumScaleFactor = 0.75
        ctaLabel.numberOfLines = 1
        ctaLabel.text = NSLocalizedString("Learn More", comment: "Learn More CTA")

        callToActionButton.addSubview(ctaLabel)
        NSLayoutConstraint.activate([
            ctaLabel.leadingAnchor.constraint(equalTo: callToActionButton.leadingAnchor, constant: 12),
            ctaLabel.trailingAnchor.constraint(equalTo: callToActionButton.trailingAnchor, constant: -12),
            ctaLabel.centerYAnchor.constraint(equalTo: callToActionButton.centerYAnchor)
        ])

        // Content Vertical Stack for clean dynamic spacing without clipping
        contentStack.axis = .vertical
        contentStack.spacing = 8
        contentStack.alignment = .fill
        contentStack.distribution = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        contentStack.addArrangedSubview(mediaView)
        contentStack.addArrangedSubview(bodyLabel)
        contentStack.addArrangedSubview(callToActionButton)

        nativeAdView.addSubview(contentStack)

        // Assign GADNativeAdView properties
        nativeAdView.mediaView = mediaView
        nativeAdView.bodyView = bodyLabel
        nativeAdView.callToActionView = callToActionButton

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),

            mediaView.heightAnchor.constraint(equalToConstant: 180),
            callToActionButton.heightAnchor.constraint(equalToConstant: 38)
        ])
    }

    func configure(with nativeAd: GADNativeAd) {
        nativeAdView.nativeAd = nativeAd

        // Media
        mediaView.mediaContent = nativeAd.mediaContent

        // Body
        if let body = nativeAd.body, !body.isEmpty {
            bodyLabel.text = body
            bodyLabel.isHidden = false
        } else {
            bodyLabel.text = nil
            bodyLabel.isHidden = true
        }

        // CTA
        let ctaTitle = nativeAd.callToAction ?? NSLocalizedString("Learn More", comment: "Learn More CTA")
        ctaLabel.text = ctaTitle
        callToActionButton.setTitle(ctaTitle, for: .normal)
        callToActionButton.setTitleColor(.clear, for: .normal)
        callToActionButton.isHidden = false
    }
}

/// SwiftUI wrapper for NativeAdMediaContainerUIView
struct NativeAdMediaAndCTAViewRepresentable: UIViewRepresentable {
    let nativeAd: GADNativeAd

    func makeUIView(context: Context) -> NativeAdMediaContainerUIView {
        let view = NativeAdMediaContainerUIView()
        view.configure(with: nativeAd)
        return view
    }

    func updateUIView(_ uiView: NativeAdMediaContainerUIView, context: Context) {
        uiView.configure(with: nativeAd)
    }
}
