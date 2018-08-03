Param(
	[Parameter(Position=0, Mandatory=$true)][String]$Music,
	[Parameter(Position=1, Mandatory=$true)][String]$Car,
	[Int[]]$Cds = @(1, 2, 3, 4, 5, 6),
	[String]$ListPath,
	[Switch]$CleanFirst,
	[Switch]$DontAdd,
	[Switch]$PrintList,
	[Parameter(ParameterSetName="Shuffle")][Switch]$Shuffle,
	[Parameter(ParameterSetName="ShuffleBand")][Switch]$ShuffleBand
)

[String[]]$cdNames = $Cds | % { "CD0$_" }

if ($cdNames.Count -eq 0) { throw "You must specify at least one cd" }

foreach ($discName in $cdNames)
{
	$discPath = "$Car/$discName"

	if (-not (Test-Path $discPath -PathType Container))
	{
		New-Item -ItemType Directory $discPath
	}
}

if ($CleanFirst)
{
	foreach ($cd in $cdNames)
	{
		Get-ChildItem "$Car/$cd" -Recurse | Remove-Item -Force
	}

	if ($ListPath.Length -gt 0 -and (Test-Path $ListPath)) { Remove-Item $ListPath }
}

if (-not $DontAdd)
{
	if ($ShuffleBand)
	{
		Write-Host -ForegroundColor Yellow "Shuffling..."

		$musicFiles = @()
		$maxItems = $cdNames.Count * 99
		$bands = Get-ChildItem $Music -Directory

		foreach ($cd in $cdNames)
		{
			$maxItems -= (Get-ChildItem $Car/$cd).Count
		}

		$start = Get-Date
		$misses = 0

		foreach ($item in 1..$maxItems)
		{
			while ($bands.Count -gt 0)
			{
				$band = ($bands | Sort-Object {Get-Random})[0]
				$songs = Get-ChildItem $band.FullName -Recurse -File -Filter "*.mp3" | Sort-Object {Get-Random}
				$added = $false

				foreach ($song in $songs)
				{
					if (-not $musicFiles.Contains($item))
					{
						$timeSpent = New-TimeSpan -Start $start
						$timeLeft = ($timeSpent.TotalSeconds / $item) * ($maxItems - $item)
						Write-Progress -Activity "Shuffling..." -Status "$item/$maxItems gathered, $misses misses" -PercentComplete (100*$item/$maxItems) -SecondsRemaining ([Math]::Ceiling($timeLeft))

						$musicFiles += $song
						$added = $true
						break
					}

					$misses += 1
				}

				if ($added) { break }

				$bands = $bands | ? { $_ -ne $band }
			}
		}

		Write-Progress -Activity "Shuffling..." -Completed
		Write-Host -ForegroundColor Yellow "Shuffled $maxItems songs."
	}
	else
	{
		$musicFiles = Get-ChildItem $Music -Recurse -File -Filter "*.mp3"

		if ($Shuffle)
		{
			$musicFiles = $musicFiles | Sort-Object {Get-Random}
		}
	}

	$disc = 0
	$item = 0
	$totalItem = 1
	$start = Get-Date

	foreach ($file in $musicFiles)
	{
		do
		{
			$item += 1
			if ($item -ge 100) { $item = 1; $disc += 1 }
			if ($disc -ge $cdNames.Count) { return }

			$discName = $cdNames[$disc]
			$discPath = "$Car/$discName"
			$newItem = "$discPath/$($item).mp3"
			$whItemName = "$($discName)x$item"
		} while (Test-Path $newItem -PathType Leaf)
		
		$fileName = $file.FullName
		Copy-Item -LiteralPath $fileName -Destination $newItem

		if (-not (Test-Path $newItem))
		{
			Write-Host -ForegroundColor Red "$newItem is missing -.-"
		}

		$timeSpent = New-TimeSpan -Start $start
		$timeLeft = ($timeSpent.TotalSeconds / $totalItem) * ($maxItems - $totalItem)
		Write-Progress -Activity "Copying..." -Status "$totalItem/$maxItems copied" -PercentComplete (100*$totalItem/$maxItems) -SecondsRemaining ([Math]::Ceiling($timeLeft))
		$totalItem += 1

		$listItem = "$whItemName <- $($fileName.Substring((Resolve-Path $Music).Path.Length + 1))"

		if ($PrintList) { Write-Host $listItem }
		if ($ListPath.Length -gt 0) { $listItem | Out-File -Append $ListPath }
	}

	Write-Progress -Activity "Copying..." -Completed
}
