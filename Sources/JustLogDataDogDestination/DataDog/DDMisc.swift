/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

/// Shared user info provider.
internal class UserInfoProvider {
    /// Ensures thread-safe access to `UserInfo`.
    /// `UserInfo` can be mutated by any user thread with `Datadog.setUserInfo(id:name:email:)` - at the same
    /// time it might be accessed by different queues running in the SDK.
    private let queue = DispatchQueue(label: "com.datadoghq.user-info-provider", qos: .userInteractive)
    private var _value = UserInfo(id: nil, name: nil, email: nil, extraInfo: [:])

    var value: UserInfo {
        set { queue.async { self._value = newValue } }
        get { queue.sync { self._value } }
    }
}

/// Information about the user.
internal struct UserInfo {
    let id: String?
    let name: String?
    let email: String?
    let extraInfo: [AttributeKey : AttributeValue]
}

typealias CarrierInfo = [String : Encodable]

/// Network connection details.
internal struct NetworkConnectionInfo {
    /// Tells if network is reachable.
    enum Reachability: String, Encodable, CaseIterable {
        /// The network is reachable.
        case yes
        /// The network might be reachable after trying.
        case maybe
        /// The network is not reachable.
        case no
    }

    /// Network connection interfaces.
    enum Interface: String, Encodable, CaseIterable {
        case wifi
        case wiredEthernet
        case cellular
        case loopback
        case other
    }

    let reachability: Reachability
    let availableInterfaces: [Interface]?
    let supportsIPv4: Bool?
    let supportsIPv6: Bool?
    let isExpensive: Bool?
    let isConstrained: Bool?
}


// MARK: - Optional
extension Optional {
    func ifNotNil(_ closure: (Wrapped) throws -> Void) rethrows {
        if case .some(let unwrappedValue) = self {
            try closure(unwrappedValue)
        }
    }
}
