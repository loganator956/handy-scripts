# Minecraft Modpack Auto Setup

This is a small powershell script that will automatically setup custom unofficial modpacks and generate/update minecraft launcher profiles.

## Usage

This is just a normal powershell script. As it is unsigned you will need to change your `ExecutionPolicy` to at least `RemoteSigned`. 

```Powershell
mc-modpack-setup.ps1 [url to json file]
```

Or you can run it using `Invoke-Expression`:

```Powershell
$MC_JSON_PATH = [URL to json];iwr https://raw.githubusercontent.com/loganator956/mc-autosetup/read-var/mc-modpack-setup.ps1 | iex
```

**REPLACE `URL to json` WITH THE ACTUAL URL**

If you do not provide an argument nor a `MC_JSON_PATH` variable value, you will be prompted to input the URL.

Currently, it will download the modpack json file using `Invoke-WebRequest` and so will not be able to install from local files. 

## Modpack Json

This repo comes with a `sample-modpack.json` file which contains pretty much a functioning modpack which can be expanded/changed to your needs.

`ModBlacklist` should be a list of **modrinth** project IDs to not download.

I also have some of my own files available in [this gist](https://gist.github.com/loganator956/07e2aa3de06df5f73e76a73cacd8487c)
