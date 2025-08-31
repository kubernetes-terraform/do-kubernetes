terraform {
  required_version = ">= 1.4.6"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.4.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4"
    }
  }

  backend "s3" {
    bucket                      = "nataliagranato"
    key                         = "do-kubernetes/terraform.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true

    endpoints = {
      s3 = "https://4839c9636a58fa9490bbe3d2e686ad98.r2.cloudflarestorage.com"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
