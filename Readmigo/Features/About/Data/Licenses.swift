import Foundation

/// Open source licenses data
struct Licenses {
    static let all: [OpenSourceLicense] = [
        OpenSourceLicense(
            name: "Alamofire",
            version: "5.8.0",
            license: .mit,
            url: URL(string: "https://github.com/Alamofire/Alamofire"),
            licenseText: mitLicense(copyright: "Copyright (c) 2014-2024 Alamofire Software Foundation (http://alamofire.org/)")
        ),
        OpenSourceLicense(
            name: "Kingfisher",
            version: "7.10.0",
            license: .mit,
            url: URL(string: "https://github.com/onevcat/Kingfisher"),
            licenseText: mitLicense(copyright: "Copyright (c) 2019 Wei Wang")
        ),
        OpenSourceLicense(
            name: "Sentry",
            version: "8.x",
            license: .mit,
            url: URL(string: "https://github.com/getsentry/sentry-cocoa"),
            licenseText: mitLicense(copyright: "Copyright (c) 2015-2024 Sentry")
        ),
        OpenSourceLicense(
            name: "SwiftSoup",
            version: "2.6.0",
            license: .mit,
            url: URL(string: "https://github.com/scinfu/SwiftSoup"),
            licenseText: mitLicense(copyright: "Copyright (c) 2016 Nabil Chatbi")
        ),
        OpenSourceLicense(
            name: "KeychainAccess",
            version: "4.2.2",
            license: .mit,
            url: URL(string: "https://github.com/kishikawakatsumi/KeychainAccess"),
            licenseText: mitLicense(copyright: "Copyright (c) 2014 kishikawa katsumi")
        ),
        OpenSourceLicense(
            name: "GoogleSignIn",
            version: "7.x",
            license: .apache2,
            url: URL(string: "https://github.com/google/GoogleSignIn-iOS"),
            licenseText: apache2License
        )
    ]

    // MARK: - License Templates

    private static func mitLicense(copyright: String) -> String {
        """
        MIT License

        \(copyright)

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
        """
    }

    private static let apache2License = """
        Apache License
        Version 2.0, January 2004
        http://www.apache.org/licenses/

        Licensed under the Apache License, Version 2.0 (the "License");
        you may not use this file except in compliance with the License.
        You may obtain a copy of the License at

            http://www.apache.org/licenses/LICENSE-2.0

        Unless required by applicable law or agreed to in writing, software
        distributed under the License is distributed on an "AS IS" BASIS,
        WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        See the License for the specific language governing permissions and
        limitations under the License.
        """
}
