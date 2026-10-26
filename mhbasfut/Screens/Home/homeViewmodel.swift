//
//  homeViewmodel.swift
//  mhbasfut
//
//  Created by Adrià Hermoso on 25/08/2026.
//

import SwiftUI
import Combine

@MainActor
public class HomeViewModel: ObservableObject {
    private let repo: HomeRepo
    
    public init(repo: HomeRepo = HomeRepo.shared) {
        self.repo = repo
    }
}
