//
//  models.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/28/25.
//

struct User: Decodable {
    let UserID: Int
    let Email: String
    let Username: String
    let CreatedAt: String
    let Name: String?
}
