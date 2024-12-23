# custom-pve-kernel
Custom Proxmox VE Kernel Build Scripts and Patches


# Notes
## Create Patch
```shell
diff -Naru file_original file_updated > mypatch.patch
```

## Apply Patch
```shell
patch --verbose -d/ -p0 <mypatch.patch
```
