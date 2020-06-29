//
//  Store+CombineSubscriber.swift
//  APITest
//
//  Created by Mathew Polzin on 6/28/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import ReSwift
import Combine

extension ReSwift.Store: Combine.Subscriber {
    public typealias Input = ReSwift.Action
    public typealias Failure = RequestFailure

    public func receive(subscription: Combine.Subscription) {
        subscription.request(.unlimited)
    }

    public func receive(_ input: Action) -> Subscribers.Demand {
        self.dispatch(input)
        return .unlimited
    }

    public func receive(completion: Subscribers.Completion<RequestFailure>) {}
}
