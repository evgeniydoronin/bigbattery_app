//  Zetara
//
//  Created by xxtx on 2023/1/4.
//

import Foundation
import RxBluetoothKit2
import CoreBluetooth
import RxSwift

public struct Identifier {
    let service: ZetaraService
    let writeCharacteristic: ZetaraCharacteristic
    let notifyCharacteristic: ZetaraCharacteristic
}

struct ZetaraService: ServiceIdentifier {
    var uuid: CBUUID

    init(uuidString: String) {
        self.uuid = CBUUID(string: uuidString)
    }
}

struct ZetaraCharacteristic: CharacteristicIdentifier {
    var uuid: CBUUID
    var service: RxBluetoothKit2.ServiceIdentifier

    init(uuidString: String, service: ZetaraService) {
        self.uuid = CBUUID(string: uuidString)
        self.service = service
    }
}

extension Identifier {
    static func asSingle(service: Service) -> Single<(service: Service, identifer: Identifier)> {
        Single.create { single in
            if let identifier = Self.identifier(of: service) {
                single(.success((service: service, identifer: identifier)))
            } else {
                single(.failure(ZetaraManager.Error.notZetaraPeripheralError))
            }

            return Disposables.create()
        }
    }

    static func identifier(of service: Service) -> Identifier? {
        return supportIdentifiers().first {
            $0.service.uuid == service.uuid
        }
    }

    static func identifier(of charateristic: Characteristic) -> Identifier? {
        return supportIdentifiers().first {
            $0.writeCharacteristic.uuid == charateristic.uuid || $0.notifyCharacteristic.uuid == charateristic.uuid
        }
    }
}

extension Array where Element == Characteristic {
    subscript(characteristicOf identifer: ZetaraCharacteristic) -> Characteristic? {
        return self.first {
            $0.uuid == identifer.uuid
        }
    }
}
