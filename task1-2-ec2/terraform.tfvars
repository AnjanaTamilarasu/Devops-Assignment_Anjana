region      = "ap-south-1"
environment = "dev"
owner       = "Owner_Anjana"

instances = {
  web-1   = { instance_type = "t3.micro",       volume_type = "gp3",      volume_size = 10, key_name = "assign-web-1" }
  web-2   = { instance_type = "t8i.micro",      volume_type = "gp2",      volume_size = 12, key_name = "assign-web-2" }
  app-1   = { instance_type = "t3.small",       volume_type = "gp3",      volume_size = 15, key_name = "assign-app-1" }
  cache-1 = { instance_type = "t8i.small",      volume_type = "standard", volume_size = 15, key_name = "assign-cache-1" }
  db-1 = {
    instance_type = "c7i-flex.large"
    volume_type   = "io1"
    volume_size   = 20
    iops          = 100
    key_name      = "assign-db-1"
    protected     = true
  }
}
