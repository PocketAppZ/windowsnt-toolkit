# Windows NT Toolkit

My personal "getting started" repository for any Windows NT-based installation.

## Setting up Essentials

Run the Chris Titus Tool to update `winget` and install `chocolatey`. I personally don't use Chocolatey, but if there's ever something I need from it then I'll install it using Chocolatey.

```powershell
irm https://christitus.com/win | iex
```

Once the tool updates `winget`, enable the `InstallerHashOverride` setting because some of the programs do not update their security hash, namely [Vencord](https://github.com/vendicated/vencord).

```powershell
winget settings --enable InstallerHashOverride
```

> [!IMPORTANT]
> Do not install programs you do not trust with `--ignore-security-hash` unless you truly know what you are doing.

So now that `InstallerHashOverride` is enabled we can install Vencord:

```powershell
winget install --source=winget --id=Vendicated.Vencord --ignore-security-hash
```

This does have to be ran as non-Administrator.