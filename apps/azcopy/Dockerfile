FROM mcr.microsoft.com/azure-cli
#Install tar
RUN tdnf install -y tar
#Install azcopy
RUN curl -sL https://aka.ms/downloadazcopy-v10-linux | tar xz -C /tmp && mv /tmp/azcopy_linux_amd64_*/azcopy /usr/local/bin/azcopy
#Run azcopy
CMD ["azcopy", "--version"]