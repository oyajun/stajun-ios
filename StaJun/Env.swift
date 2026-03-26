//
//  Env.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/21.
//

#if DEBUG
let ENV_BASEURL = "http://192.168.128.192:3000/"
//let ENV_BASEURL = "http://localhost:3000/"

#else //PRODUCTION
let ENV_BASEURL = "http://localhost:3000/"

#endif
