import yaml
import sys
from typing import Optional
from pydantic import model_validator, ValidationError
from validators.base import StrictModel, EnvironmentEnum
from validators.modules.networking import Networking
from validators.modules.compute import Compute
from validators.modules.storage import Storage
from validators.modules.security import Security
from validators.modules.databases import Databases
from validators.modules.messaging import Messaging


################################################
# CATALOG
################################################
class Catalog(StrictModel):
    networking: Optional[Networking] = None
    compute:    Optional[Compute]    = None
    storage:    Optional[Storage]    = None
    security:   Optional[Security]   = None
    databases:  Optional[Databases]  = None
    messaging:  Optional[Messaging]  = None

    @model_validator(mode='after')
    def validate_at_least_one_module(self):
        if not any([self.networking, self.compute, self.storage,
                    self.security, self.databases, self.messaging]):
            raise ValueError(
                "catalog debe tener al menos un módulo: "
                "networking, compute, storage, security, databases o messaging"
            )
        return self

    @model_validator(mode='after')
    def validate_depends_on(self):
        all_modules = [
            'networking', 'compute', 'storage',
            'security', 'databases', 'messaging'
        ]

        for name in all_modules:
            module = getattr(self, name, None)
            if not module:
                continue
            for dep in module.depends_on:
                if dep not in all_modules:
                    raise ValueError(
                        f"El módulo '{name}' depende de '{dep}' "
                        f"pero '{dep}' no es un módulo válido. "
                        f"Módulos válidos: {all_modules}"
                    )
        return self


################################################
# CONFIG RAÍZ
################################################

class Network(StrictModel):
    source:                str
    stack_name:            str
    private_subnet_prefix: str = "PrivateSubnet"


class Globals(StrictModel):
    network: Network


class Config(StrictModel):
    account:      str
    environment:  EnvironmentEnum
    project_name: str
    globals:      Globals
    catalog:      Optional[Catalog] = None


###############################################
# MAIN
###############################################

def validate(config_path):
    print(f"\n==> Validando: {config_path}\n")

    with open(config_path) as f:
        raw = yaml.safe_load(f)

    try:
        Config(**raw)
        print("\n✓ Validación completa exitosa\n")
    except ValidationError as e:
        print("ERROR: Validación fallida:\n")
        for err in e.errors():
            location = " -> ".join(str(x) for x in err['loc'])
            print(f"  ✗ {location}: {err['msg']}")
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Uso: python3 -m validators.main <config.yml>")
        sys.exit(1)

    validate(sys.argv[1])