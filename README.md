# terrapache

# Tested Using
- Windows 8.1 (I know; I'm sorry)
- Git Bash 2.14.2.3
- Terraform 0.11.13


# Deployment
- Download `terraform` for your platform & ensure that `terraform` is in your path
  - https://www.terraform.io/downloads.html
- `git clone` this repository and `cd` into it
- `terraform init && terraform apply -auto-approve -var 'access_key=<your_aws_access_key>' -var 'secret_key=<your_aws_secret_key>'`
- And you're done!
- For the sake of ease, `apply` output will be of the following format:
  - ```
    lb_url = http://<aws_alb_hostname>
    webserver_public_ips = <public_ip_address_1>, <public_ip_address_2>, ...
    ```
- SSH to your webservers using the terraform-generated private key in `id_rsa`