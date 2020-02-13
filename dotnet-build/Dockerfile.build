# 1) Launch Windows Server 2016 With Containers AMI instance
# 2) Install AWS CLI
#     Invoke-WebRequest -UseBasicParsing https://s3.amazonaws.com/aws-cli/AWSCLI64PY3.msi -OutFile AWSCLI64PY3.msi
#     msiexec /i AWSCLI64PY3.msi /q
#     aws s3 sync s3://artifacts.int.build.briggo.io/3rd-party 3rd-party/ --sse
#    ./Git-2.23.0-64-bit.exe /VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /COMPONENTS="icons,ext\reg\shellhere,assoc,assoc_sh"
#
#
# 3) Make working dir c:\BuildTools
# 4) Download assets from s3://artifacts.int.build.briggo.io/3rd-party/
# 5) Run Docker Build
#    https://aws.amazon.com/blogs/devops/extending-aws-codebuild-with-custom-build-environments-for-the-net-framework/
#    docker build -t 556085509259.dkr.ecr.us-east-1.amazonaws.com/build/dotnet-build:4.8-2016 -m 2GB .
#    Invoke-Expression -Command (aws ecr get-login --registry-ids 556085509259)
#    docker push

# escape=`
FROM microsoft/dotnet-framework:4.7.2-runtime

#SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'Continue'; $verbosePreference='Continue';"]

#Install NuGet CLI
ENV NUGET_VERSION 5.2.0
RUN New-Item -Type Directory $Env:ProgramFiles\NuGet; \
    Invoke-WebRequest -UseBasicParsing https://dist.nuget.org/win-x86-commandline/v$Env:NUGET_VERSION/nuget.exe -OutFile $Env:ProgramFiles\NuGet\nuget.exe

# Install VS Test Agent
RUN Invoke-WebRequest -UseBasicParsing https://download.visualstudio.microsoft.com/download/pr/12210068/8a386d27295953ee79281fd1f1832e2d/vs_TestAgent.exe -OutFile vs_TestAgent.exe; \
    Start-Process vs_TestAgent.exe -ArgumentList '--quiet', '--norestart', '--nocache' -NoNewWindow -Wait; \
    Remove-Item -Force vs_TestAgent.exe; \
  # Install VS Build Tools
    Invoke-WebRequest -UseBasicParsing https://download.visualstudio.microsoft.com/download/pr/12210059/e64d79b40219aea618ce2fe10ebd5f0d/vs_BuildTools.exe -OutFile vs_BuildTools.exe; \
  # Installer won't detect DOTNET_SKIP_FIRST_TIME_EXPERIENCE if ENV is used, must use setx /M
    setx /M DOTNET_SKIP_FIRST_TIME_EXPERIENCE 1; \
    Start-Process vs_BuildTools.exe -ArgumentList '--add', 'Microsoft.VisualStudio.Workload.MSBuildTools', '--add', 'Microsoft.VisualStudio.Workload.NetCoreBuildTools', '--add', 'Microsoft.VisualStudio.Workload.WebBuildTools;includeRecommended', '--quiet', '--norestart', '--nocache' -NoNewWindow -Wait; \
    Remove-Item -Force vs_buildtools.exe; \
    Remove-Item -Force -Recurse \"${Env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\"; \
    Remove-Item -Force -Recurse ${Env:TEMP}\*;
#    Remove-Item -Force -Recurse \"${Env:ProgramData}\Package Cache\"

# Set PATH in one layer to keep image size down.
RUN setx /M PATH $(${Env:PATH} \
    + \";${Env:ProgramFiles}\NuGet\" \
    + \";${Env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\TestAgent\Common7\IDE\CommonExtensions\Microsoft\TestWindow\" \
    + \";${Env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\BuildTools\MSBuild\15.0\Bin\")

# Install Targeting Packs
RUN @('4.0', '4.5.2', '4.6.2', '4.7.2') \
    | %{ \
        Invoke-WebRequest -UseBasicParsing https://dotnetbinaries.blob.core.windows.net/referenceassemblies/v${_}.zip -OutFile referenceassemblies.zip; \
        Expand-Archive -Force referenceassemblies.zip -DestinationPath \"${Env:ProgramFiles(x86)}\Reference Assemblies\Microsoft\Framework\.NETFramework\"; \
        Remove-Item -Force referenceassemblies.zip; \
    }

# Install Cygwin, NodeJS, Git (minimal, for bash)
RUN Invoke-WebRequest https://chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression
RUN choco install cygwin nodejs git -y

# Install SemVer and Eclipse Build tools (GNU make)
RUN npm install --global xpm semver
RUN xpm install --global @gnu-mcu-eclipse/windows-build-tools; \
    setx /M PATH $('C:\Users\ContainerAdministrator\AppData\Roaming\xPacks\@gnu-mcu-eclipse\windows-build-tools\2.12.1-1\.content\bin;{0}' -f $env:PATH)

# Install wintpy
COPY winpty-0.4.3-cygwin-2.8.0-x64.zip c:/
RUN Expand-Archive -Force c:/winpty-0.4.3-cygwin-2.8.0-x64.zip -DestinationPath "c:/";

# Install Git Bash
COPY Git-2.23.0-64-bit.exe c:/
RUN c:/Git-2.23.0-64-bit.exe /VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /COMPONENTS="icons,ext\reg\shellhere,assoc,assoc_sh"
#RUN Remove-Item -Force c:/temp/Git-2.23.0-64-bit.exe;
