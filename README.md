# Right, what's all this then?
This is a collection of scripts and automations that I use/am working on. I put them into a GIT repo so I could shuffle them around easier, however the repo is not autonomous. It expects a jump host/dev VM (though a lot of that setup has been automated too) with credentials to the machines it is to manage.

# Folders
This changes from time to time; I'll try to keep it updated. Ideally, this toolset is meant to be run from the root folder, this avoids relying too heavily on `../` but it's not possible to implement that all the time.

## ansible
A collection of useful stuff for Ansible, incleading a readme with common ansible commands and an inventory of my machines/IPs. Perfect for publishing on the internet...

### playbooks
Ansible playbooks for common administration tasks.

### kubernetes
Can provision an Ubuntu 22.04 Server > ready-to-join Kubernetes node. This is a *tool*; additional documentation is in the folder.

# Concifuration Recipes
These range from a collection of commands looped into a `.sh`, to actual scripts that I plan on writing. Help with annoying tasks that I do often. These aren't great, because my bash is pretty bad (I get paid to write PowerShell, and in comparison BASH is a hard sell), but they're better than nothing.

## norun-scripts
Absolutely do not run, use them as workbooks. They're mostly made of garbage, they don't run but the commands are annoying to find on the internet and here they're in one place.

## var-scripts
These have variables that need to be edited, that I was too lazy to parameterize as prompts. Open, configure, run.

## scripts
These will probably work fine, or have some basic error handling to keep them from breaking everything.