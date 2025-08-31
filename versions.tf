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
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "digitalocean" {
  token = var.do_pat
}
