# Technical-Task

This is the terraform code for deploying two VMs and a load-balancer in azure.

To start, run the command:
1.terraform init
2.terraform plan
3.terraform apply

If an error occurs, repeat the terraform apply command

Terraform is set to automatically deploy the script from the IIS_Config.ps1 file

This script can also be run locally

1.Connect to Azure
Connect-AzAccount

2. Execute the command for each machine
Invoke-AzVMRunCommand -ResourceGroupName test-grp -Name test-vm1 -CommandId 'RunPowerShellScript' -ScriptPath .\IIS_script.ps1

Working link - http://20.125.150.79/
