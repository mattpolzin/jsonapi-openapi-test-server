//
//  Optional+zip.swift
//  SwiftGen
//
//  Created by Mathew Polzin on 10/6/19.
//

func zip<T, U>(_ first: T?, _ second: U?) -> (T, U)? {
    return first.flatMap { fst in second.map { scd in (fst, scd) } }
}
