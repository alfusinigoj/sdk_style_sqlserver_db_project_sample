Properties {
    $base_dir = Resolve-Path .

    $tools_dir = "$base_dir/tools"
    $temp_tools_dir = "$base_dir/temp-tools"

    $local_db_password = "AlwaysBeKind@"
    $local_db_container_name = "Sample.DB"
    $local_db_container_port = 2000
    $db_project_file = "$base_dir/database/Sample.DB/Sample.DB.sqlproj"
    $db_publish_dir = "$base_dir/publish-artifacts/db"
    $db_connection_str = "Server=localhost,$local_db_container_port;Database=Sample;User Id=sa;Password=$local_db_password;"
}

#These are aliases for other build tasks. They typically are named after the camelcase letters (rd = Rebuild Databases)
Task default -depends Soup2Nuts

#These are the actual build tasks. They should be Pascal case by convention
Task Soup2Nuts -depends RebuildSqlServerContainer, CompileDb, DeployDb

Task RebuildSqlServerContainer {
    Write-Host "******************* Now rebuilding docker container *********************"  -ForegroundColor Green
    Exec {
        docker rm -f $local_db_container_name
        docker run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=$local_db_password" -p $local_db_container_port':1433' --name $local_db_container_name -d mcr.microsoft.com/mssql/server:2019-latest
    }
}

Task CompileDb {
    Write-Host "******************* Now compiling the database *********************"  -ForegroundColor Green
    delete_directory($db_publish_dir)
    Exec {
        & dotnet msbuild /t:restore $db_project_file /v:m 
        & dotnet msbuild /t:build /p:OutDir=$db_publish_dir /p:NetCoreBuild=true $db_project_file /v:m
    }
}

Task DeployDb {
    Write-Host "******************* Now deploying $db_publish_dir/Sample.DB.dacpac *********************"  -ForegroundColor Green
    
    create_directory($temp_tools_dir)
    $env:ConnectionStrings:SampleDatabase = $db_connection_str

    # Reference: https://docs.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage-download?view=sql-server-ver15
    Exec {
        if($IsMacOS)
        {
            Write-Host "Running in MacOS"  -ForegroundColor Blue
            Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2185765" -OutFile "$temp_tools_dir/sqlpackage-osx.zip"
            Expand-Archive -Path "$temp_tools_dir/sqlpackage-osx.zip" -DestinationPath "$temp_tools_dir/sqlpackage" -Force
            & chmod +x "$temp_tools_dir/sqlpackage/sqlpackage"
        }
        elseif($IsLinux)
        {
            Write-Host "Running in Linux"  -ForegroundColor Blue
            Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2185670" -OutFile "$temp_tools_dir/sqlpackage-linux.zip"
            Expand-Archive -Path "$temp_tools_dir/sqlpackage-linux.zip" -DestinationPath "$temp_tools_dir/sqlpackage" -Force
            & chmod +x "$temp_tools_dir/sqlpackage/sqlpackage"
        }
        else
        {
            Write-Host "Running in Windows"  -ForegroundColor Blue
            Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2185669" -OutFile "$temp_tools_dir/sqlpackage-win.zip"
            Expand-Archive -Path "$temp_tools_dir/sqlpackage-win.zip" -DestinationPath "$temp_tools_dir/sqlpackage" -Force
        }

        & $temp_tools_dir/sqlpackage/sqlpackage /Action:Publish /SourceFile:"$db_publish_dir/Sample.DB.dacpac" /tcs:$db_connection_str /p:BlockOnPossibleDataLoss=true
    }
}

function global:delete_directory($directory_name) {
    Remove-Item $directory_name -Recurse -Force  -ErrorAction SilentlyContinue | Out-Null
}

function global:create_directory($directory_name) {
    New-Item $directory_name -Force  -ItemType "directory" -ErrorAction SilentlyContinue | Out-Null
}