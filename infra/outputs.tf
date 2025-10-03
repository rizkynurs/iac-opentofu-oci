output "public_ip" {
  value       = oci_core_instance.vm.public_ip
  description = "Public IP of the VM"
}

output "nginx_url" {
  value = "http://${oci_core_instance.vm.public_ip}"
}

output "grafana_tunnel_hint" {
  value       = "ssh -L 3000:localhost:3000 ubuntu@${oci_core_instance.vm.public_ip}"
  description = "SSH tunnel to access Grafana securely"
}
