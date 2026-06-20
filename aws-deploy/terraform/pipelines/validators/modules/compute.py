import re
from typing import Optional, List
from pydantic import field_validator, model_validator, Field
from validators.base import StrictModel, ImageTagMutabilityEnum, EncryptionTypeEnum


class LifecyclePolicy(StrictModel):
    keep_last_images:           int = 10
    expire_untagged_after_days: int = 7


class ECRRepository(StrictModel):
    name:                 str
    create:               bool                      = True
    create_ssm_parameter: bool                      = False
    existing_uri:         Optional[str]             = None
    image_tag_mutability: ImageTagMutabilityEnum     = ImageTagMutabilityEnum.MUTABLE
    scan_on_push:         bool                      = True
    encryption_type:      EncryptionTypeEnum         = EncryptionTypeEnum.KMS
    kms_key_arn:          Optional[str]             = None
    lifecycle_policy:     Optional[LifecyclePolicy] = None
    allow_account_ids:    List[str]                 = []
    tags:                 Optional[dict]            = {}

    @field_validator('kms_key_arn')
    @classmethod
    def validate_kms_arn(cls, v):
        if v is None:
            return v
        if not re.match(r'^arn:aws:kms:[a-z0-9\-]+:\d{12}:.+$', v):
            raise ValueError(
                f"'{v}' no es un KMS ARN válido. "
                f"Formato esperado: arn:aws:kms:region:123456789012:key/..."
            )
        return v


class ECSCluster(StrictModel):
    name:               str
    create:             bool           = False
    container_insights: Optional[bool] = None
    tags:               Optional[dict] = {}


class TaskDefinition(StrictModel):
    cpu:                           int           = 256
    memory:                        int           = 512
    image_version:                 Optional[str] = "latest"
    image_version_ssm:             Optional[str] = None   
    image_repo_uri:                Optional[str] = None
    use_placeholder:               bool          = False   
    placeholder_image:             str           = "public.ecr.aws/nginx/nginx:alpine"
    container_port:                int           = Field(default=8080, ge=1, le=65535)
    desired_count:                 int           = Field(default=1, ge=0)
    enable_container_health_check: bool          = False
    health_check_path:             str           = "/"
    health_check_grace_period:     int           = 60
    task_role_create:              bool          = True
    task_role_arn:                 Optional[str] = None
    task_managed_policies:         List[str]     = []
    s3_bucket_names:               List[str]     = []
    s3_actions:                    List[str]     = ["s3:GetObject", "s3:ListBucket"]
    log_retention_days:            int           = 30

    @field_validator('cpu')
    @classmethod
    def validate_cpu(cls, v):
        valid = [256, 512, 1024, 2048, 4096]
        if v not in valid:
            raise ValueError(f"cpu={v} no es válido en Fargate. Valores válidos: {valid}")
        return v
      

    @model_validator(mode='after')
    def validate_cpu_memory(self):
        valid_cpu_memory = {
            256:  [512],
            512:  [1024, 2048],
            1024: [2048, 3072, 4096],
            2048: [4096, 5120, 6144, 7168, 8192],
            4096: [8192, 9216, 10240, 11264, 12288, 13312, 14336, 15360, 16384],
        }
        return self

    @model_validator(mode='after')
    def validate_task_role(self):
        if self.task_role_arn and self.task_role_create:
            raise ValueError("'task_role_arn' solo aplica si 'task_role_create: false'")
        return self

    @model_validator(mode='after')
    def validate_image_version_ssm_and_placeholder(self):
        # ADDED: si use_placeholder=True, image_version_ssm no aplica
        if self.use_placeholder and self.image_version_ssm:
            raise ValueError(
                "'image_version_ssm' no aplica cuando 'use_placeholder: true'"
            )
        return self


class Autoscaling(StrictModel):
    enabled:    bool = True
    min:        int = 1
    max:        int = 4
    target_cpu: int = 80


class ECSService(StrictModel):
    name:              str
    cluster:           str
    ecr:               Optional[str]            = None
    elb:               Optional[str]            = None
    namespace:         Optional[str]            = None
    base_path:         str                      = "/"
    listener_priority: int                      = Field(default=1, ge=1)  # FIXED: ge=1
    task:              Optional[TaskDefinition] = None
    autoscaling:       Optional[Autoscaling]    = None
    secrets:           List[str]                = []   # ADDED: secretos de Secrets Manager
    tags:              Optional[dict]           = {}


class EBSVolume(StrictModel):
    device_name: str
    size:        int = Field(default=100, ge=1)
    type:        str = "gp3"
    encrypted:   bool = True
    iops:        Optional[int] = None
    throughput:  Optional[int] = None


class IngressRule(StrictModel):
    from_port:   int
    to_port:     int
    protocol:    str
    cidr_blocks: Optional[List[str]] = None
    description: Optional[str] = None


class EC2Instance(StrictModel):
    name:                      str
    os_type:                   str            = "linux"
    instance_type:             str            = "t3.micro"
    ami_id:                    Optional[str]  = None
    subnet_group:              Optional[str]  = None
    eni_name:                  Optional[str]  = None
    key_name:                  Optional[str]  = None
    enable_ssm:                bool           = True
    enable_rdp:                bool           = False
    root_volume_size:          Optional[int]  = None
    root_volume_type:          str            = "gp3"
    root_volume_encrypted:     bool           = True
    ebs_volumes:               Optional[List[EBSVolume]]   = None
    user_data:                 Optional[str]  = None
    user_data_file:            Optional[str]  = None
    create_asg:                bool           = False
    asg_min_size:              int            = 1
    asg_max_size:              int            = 3
    asg_desired_size:          int            = 1
    on_demand_base_capacity:   int            = 1
    on_demand_percentage:      int            = 100
    spot_instance_pools:       int            = 2
    additional_instance_types: Optional[List[str]]         = None
    additional_sg_ids:         Optional[List[str]]         = None
    ingress_rules:             Optional[List[IngressRule]] = None
    secrets:                   List[str]      = []   # ADDED: secretos de Secrets Manager
    tags:                      Optional[dict] = {}

    @field_validator('os_type')
    @classmethod
    def validate_os_type(cls, v):
        valid = ['linux', 'windows']
        if v not in valid:
            raise ValueError(f"os_type='{v}' no es válido. Valores válidos: {valid}")
        return v

    @field_validator('instance_type')
    @classmethod
    def validate_instance_type(cls, v):
        if not re.match(r'^[a-z0-9]+\.[a-z0-9]+$', v):
            raise ValueError(f"instance_type='{v}' no tiene formato válido (ej: t3.micro, m5.large)")
        return v

    @field_validator('root_volume_size')
    @classmethod
    def validate_root_volume_size(cls, v):
        if v is None:
            return v
        if v < 1 or v > 1024:
            raise ValueError(f"root_volume_size={v} debe estar entre 1 y 1024 GB")
        return v

    @field_validator('root_volume_type')
    @classmethod
    def validate_root_volume_type(cls, v):
        valid = ['gp2', 'gp3', 'io1', 'io2', 'st1', 'sc1']
        if v not in valid:
            raise ValueError(f"root_volume_type='{v}' no es válido. Valores válidos: {valid}")
        return v

    @field_validator('asg_min_size', 'asg_max_size', 'asg_desired_size')
    @classmethod
    def validate_asg_sizes(cls, v):
        if v < 0 or v > 100:
            raise ValueError(f"Tamaño ASG debe estar entre 0 y 100")
        return v

    @field_validator('on_demand_percentage')
    @classmethod
    def validate_on_demand_percentage(cls, v):
        if v < 0 or v > 100:
            raise ValueError(f"on_demand_percentage={v} debe estar entre 0 y 100")
        return v

    @model_validator(mode='after')
    def validate_asg_config(self):
        if self.create_asg:
            if self.asg_min_size > self.asg_max_size:
                raise ValueError(
                    f"asg_min_size ({self.asg_min_size}) no puede ser mayor que "
                    f"asg_max_size ({self.asg_max_size})"
                )
            if self.asg_desired_size < self.asg_min_size or self.asg_desired_size > self.asg_max_size:
                raise ValueError(
                    f"asg_desired_size ({self.asg_desired_size}) debe estar entre "
                    f"asg_min_size ({self.asg_min_size}) y asg_max_size ({self.asg_max_size})"
                )
        return self

    @model_validator(mode='after')
    def validate_user_data(self):
        if self.user_data and self.user_data_file:
            raise ValueError("No puedes especificar ambos 'user_data' y 'user_data_file'")
        return self

    @model_validator(mode='after')
    def validate_rdp_on_linux(self):
        if self.os_type == 'linux' and self.enable_rdp:
            raise ValueError("'enable_rdp' no puede ser true en instancias Linux")
        return self


class NodeGroup(StrictModel):
    name:          str
    instance_types: List[str]
    desired_size:  int  = 1
    min_size:      int  = 1
    max_size:      int  = 4
    disk_size:     int  = 20
    capacity_type: str  = "ON_DEMAND"
    labels:        Optional[dict]       = None
    taints:        Optional[List[dict]] = None
    tags:          Optional[dict]       = {}

    @field_validator('instance_types')
    @classmethod
    def validate_instance_types(cls, v):
        if not v or len(v) == 0:
            raise ValueError("'instance_types' no puede estar vacío")
        return v

    @field_validator('capacity_type')
    @classmethod
    def validate_capacity_type(cls, v):
        valid = ['ON_DEMAND', 'SPOT']
        if v not in valid:
            raise ValueError(f"capacity_type='{v}' no es válido. Valores válidos: {valid}")
        return v

    @field_validator('desired_size', 'min_size', 'max_size')
    @classmethod
    def validate_sizes(cls, v):
        if v < 0 or v > 100:
            raise ValueError(f"Tamaño debe estar entre 0 y 100")
        return v

    @field_validator('disk_size')
    @classmethod
    def validate_disk_size(cls, v):
        if v < 1 or v > 1000:
            raise ValueError(f"disk_size={v} debe estar entre 1 y 1000 GB")
        return v

    @model_validator(mode='after')
    def validate_node_size_config(self):
        if self.min_size > self.max_size:
            raise ValueError(
                f"min_size ({self.min_size}) no puede ser mayor que "
                f"max_size ({self.max_size})"
            )
        if self.desired_size < self.min_size or self.desired_size > self.max_size:
            raise ValueError(
                f"desired_size ({self.desired_size}) debe estar entre "
                f"min_size ({self.min_size}) y max_size ({self.max_size})"
            )
        return self


class FargateProfile(StrictModel):
    name:      str
    namespace: str
    labels:    Optional[dict] = None
    tags:      Optional[dict] = {}

    @field_validator('name', 'namespace')
    @classmethod
    def validate_required_fields(cls, v):
        if not v or v.strip() == "":
            raise ValueError("Campo no puede estar vacío")
        return v.lower()


class EKSCluster(StrictModel):
    name:                            str
    kubernetes_version:              Optional[str]              = None
    enable_irsa:                     bool                       = False
    authentication_mode:             str                        = "API_AND_CONFIG_MAP"  
    access_entries:                  List[dict]                 = []                    
    enable_load_balancer_controller: bool                       = False                 
    node_groups:                     Optional[List[NodeGroup]]      = None
    fargate_profiles:                Optional[List[FargateProfile]] = None
    addon_coredns_version:           Optional[str]              = None
    addon_kube_proxy_version:        Optional[str]              = None
    addon_vpc_cni_version:           Optional[str]              = None
    secrets:                         List[str]                  = []   
    create:                          bool                       = False
    tags:                            Optional[dict]             = {}

    @field_validator('name')
    @classmethod
    def validate_cluster_name(cls, v):
        if not v or len(v) < 1 or len(v) > 100:
            raise ValueError("'name' debe tener entre 1 y 100 caracteres")
        return v

    @field_validator('kubernetes_version')
    @classmethod
    def validate_k8s_version(cls, v):
        # ADDED: validar formato X.Y (ej: "1.29")
        if v and not re.match(r'^\d+\.\d+$', v):
            raise ValueError(
                f"kubernetes_version='{v}' debe tener formato 'X.Y' (ej: '1.29', '1.30')"
            )
        return v

    @field_validator('authentication_mode')
    @classmethod
    def validate_authentication_mode(cls, v):
        # ADDED
        valid = ['API', 'CONFIG_MAP', 'API_AND_CONFIG_MAP']
        if v not in valid:
            raise ValueError(
                f"authentication_mode='{v}' no es válido. Valores válidos: {valid}"
            )
        return v

    @model_validator(mode='after')
    def validate_node_and_fargate(self):
        if not self.node_groups and not self.fargate_profiles:
            raise ValueError(
                "Debes especificar al menos 'node_groups' o 'fargate_profiles'"
            )
        return self

    @model_validator(mode='after')
    def validate_node_group_names(self):
        if self.node_groups:
            names = [ng.name for ng in self.node_groups]
            if len(names) != len(set(names)):
                raise ValueError("Los nombres de node_groups deben ser únicos")
        return self

    @model_validator(mode='after')
    def validate_fargate_profile_names(self):
        if self.fargate_profiles:
            names = [fp.name for fp in self.fargate_profiles]
            if len(names) != len(set(names)):
                raise ValueError("Los nombres de fargate_profiles deben ser únicos")
        return self


class Compute(StrictModel):
    depends_on:       List[str]                     = []
    ecs_clusters:     Optional[List[ECSCluster]]    = None
    ecr_repositories: Optional[List[ECRRepository]] = None
    ecs_services:     Optional[List[ECSService]]    = None
    ec2_instances:    Optional[List[EC2Instance]]   = None
    eks_clusters:     Optional[List[EKSCluster]]    = None

    @model_validator(mode='after')
    def validate_service_references(self):
        cluster_names = {c.name for c in self.ecs_clusters or []}
        ecr_names     = {e.name for e in self.ecr_repositories or []}

        for svc in self.ecs_services or []:
            if svc.cluster and cluster_names and svc.cluster not in cluster_names:
                raise ValueError(
                    f"ecs_services '{svc.name}': 'cluster: {svc.cluster}' "
                    f"no existe en ecs_clusters"
                )
            if svc.ecr and ecr_names and svc.ecr not in ecr_names:
                raise ValueError(
                    f"ecs_services '{svc.name}': 'ecr: {svc.ecr}' "
                    f"no existe en ecr_repositories"
                )
        return self

    @model_validator(mode='after')
    def validate_ec2_instances(self):
        if self.ec2_instances:
            names = [i.name for i in self.ec2_instances]
            if len(names) != len(set(names)):
                raise ValueError("Los nombres de ec2_instances deben ser únicos")
        return self

    @model_validator(mode='after')
    def validate_eks_clusters(self):
        if self.eks_clusters:
            names = [c.name for c in self.eks_clusters]
            if len(names) != len(set(names)):
                raise ValueError("Los nombres de eks_clusters deben ser únicos")
        return self