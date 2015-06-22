#!/bin/bash

# Este fichero está pensado para instalar todo lo necesario para poder 
# utilizar la impresora DIMA BOX en la distribución Ubuntu MAX, de la
# Comunidad de Madrid.

# Se encontrará en el mismo directorio que las carpetas: "RepetierHost", 
# "Slic3r" y "Configuraciones" al ser ejecutado.

# Instalará y configurará ambos programas para el usuario actual, que se
# entiende con privilegios de administrador. Para poder configurar después
# el sistema para la utilización de Repetier-Host y la impresora en un 
# usuario sin privilegios, ver las instrucciones al final.

DEBUG=0 # Poner a 1 para ver todas las salidas

# Función para saber quién ejecutó el script
function findUser() {
    thisPID=$$
    origUser=$(whoami)
    thisUser=$origUser

    while [ "$thisUser" = "$origUser" ]
    do
        ARR=($(ps h -p$thisPID -ouser,ppid;))
        thisUser="${ARR[0]}"
        myPPid="${ARR[1]}"
        thisPID=$myPPid
    done

    getent passwd "$thisUser" | cut -d: -f1
}

user=$(findUser)

if [[ $(id -u) -ne 0 ]] ; then echo "Este script debe ser ejecutado con privilegios de administrador (mediante el comando sudo)." ; exit 1 ; fi

DIR=`pwd`
OSBIT=`uname -m`

echo "
Bienvenido al programa de instalación del software de la impresora DIMA BOX."

#Escoger una u otra versión de CuraEngine en función de si el sistema es de 32 o de 64 bits
if [ ${OSBIT} = "i686" ]; then
	cp RepetierHost/plugins/CuraEngine/CuraEngine32 RepetierHost/plugins/CuraEngine/CuraEngine
else
	cp RepetierHost/plugins/CuraEngine/CuraEngine64 RepetierHost/plugins/CuraEngine/CuraEngine
fi

#Añadiendo los repositorios necesarios
echo "
Instalando los paquetes necesarios..."
echo "	- Añadiendo claves GPG..."
if [ ${DEBUG} -ne 0 ]; then
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
else
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF > /dev/null 2> /dev/null
fi
echo "	- Añadiendo los repositorios necesarios..."
if [ ${DEBUG} -ne 0 ]; then
	echo "deb http://download.mono-project.com/repo/debian wheezy main" | tee /etc/apt/sources.list.d/mono-xamarin.list
else
	echo "deb http://download.mono-project.com/repo/debian wheezy main" | tee /etc/apt/sources.list.d/mono-xamarin.list > /dev/null
fi
if [ ${DEBUG} -ne 0 ]; then
	echo "deb http://download.mono-project.com/repo/debian wheezy-libtiff-compat main" | tee -a /etc/apt/sources.list.d/mono-xamarin.list > /dev/null
else
	echo "deb http://download.mono-project.com/repo/debian wheezy-libtiff-compat main" | tee -a /etc/apt/sources.list.d/mono-xamarin.list > /dev/null
fi
if [ ${DEBUG} -ne 0 ]; then
	aptitude update
else
	aptitude update > /dev/null > /dev/null
fi
echo "	- Descargando e instalando los paquetes..."
if [ ${DEBUG} -ne 0 ]; then
	aptitude -y install mono-complete build-essential libwx-perl
else
	aptitude -y install mono-complete build-essential libwx-perl > /dev/null
fi

#Creando el fichero ejecutable
echo "
Creando el fichero ejecutable..."
echo "#!/bin/sh" > RepetierHost/repetierHost
echo "cd ${DIR}/RepetierHost" >> RepetierHost/repetierHost
echo "mono RepetierHost.exe -home ${DIR}&" >> RepetierHost/repetierHost
chmod 755 RepetierHost/repetierHost
chmod a+rx ${DIR}/RepetierHost
chmod -R a+r RepetierHost/*
chmod -R a+x RepetierHost/data
rm /usr/bin/repetierHost
ln -s ${DIR}/RepetierHost/repetierHost /usr/bin/repetierHost

# Comprobando si el usuario está en el grupo dialout.
echo "
Comprobando si este usuario está en el grupo dialout..."
if [ `grep $user /etc/group | grep -c dialout` -ne 0 ]; then
  echo "	- El usuario ya está en el grupo dialout, no es necesario añadirlo."
else
  echo "	- Añadiendo al usuario ${user} al grupo dialout."
   usermod -a -G dialout $user
  echo "	AVISO: Necesitarás volver a iniciar sesión con este usuario para poder conectarte a la impresora."
fi

# Compilando una ayuda para poder utilizar baudrates distintos a los ANSI en algunas placas, dependiendo del driver USB a usar
g++ RepetierHost/SetBaudrate.cpp -o RepetierHost/SetBaudrate

# Creando los ficheros de configuración de Repetier y Slic3r
echo "
Configurando los programas..."
echo "	- Añadiendo los valores apropiados de instalación en los ficheros de configuración..."
echo "<MWFConfig>
  <FileDialog>
    <value name=\"FileNames\" type=\"string-array\">
      <string>$DIR/Slic3r/bin/slic3r</string>
    </value>
    <value name=\"Height\" type=\"int\">385</value>
    <value name=\"X\" type=\"int\">402</value>
    <value name=\"Width\" type=\"int\">555</value>
    <value name=\"Y\" type=\"int\">129</value>
    <value name=\"LastFolder\" type=\"string\">$DIR/Slic3r/bin</value>
  </FileDialog>
  <FolderBrowserDialog>
    <value name=\"Width\" type=\"int\">330</value>
    <value name=\"Y\" type=\"int\">160</value>
    <value name=\"X\" type=\"int\">518</value>
    <value name=\"Height\" type=\"int\">351</value>
  </FolderBrowserDialog>
</MWFConfig>" > $DIR/Configuraciones/.mono/mwf_config

echo "<values>
<value name=\"executable\" type=\"string\">$DIR/Slic3r/bin/slic3r</value>
<value name=\"version\" type=\"int\">2</value>
<value name=\"showPlater\" type=\"int\">0</value>
<value name=\"configDir\" type=\"string\"/></values>" > $DIR/Configuraciones/.mono/registry/CurrentUser/software/repetier/slicers/slic3r/slic3r/values.xml


#Moviendo las carpetas de configuración a su lugar en la carpeta home de este usuario
echo "	- Creando las carpetas de configuración..."
cp -r Configuraciones/.mono Configuraciones/.Slic3r /home/$user


chown -R $user /home/$user/.mono /home/$user/.Slic3r
chmod -R 755 /home/$user/.mono /home/$user/.Slic3r

#Creando un acceso directo a Repetier en el escritorio
echo "
Creando un acceso directo en el escritorio..."
echo "[Desktop Entry]
Name=Repetier-Host
Exec=repetierHost
Type=Application
StartupNotify=true
Comment=Repetier-Host 3d printer host software
Path=$DIR/RepetierHost
Icon=$DIR/RepetierHost/repetier-logo.png
Comment[en_US.UTF-8]=Repetier Host
Name[en_US]=Repetier-Host
" > Repetier-Host.desktop
chown $user Repetier-Host.desktop
chmod 755 Repetier-Host.desktop

mv Repetier-Host.desktop $(xdg-user-dir DESKTOP)

echo "
Los programas Repetier-Host y Slic3r han sido instalados y configurados para ser usados con la DIMA BOX.
" 

# Para que otro usuario de la máquina, sin privilegios, pueda utilizar la máquina, se deben seguir los siguientes pasos:
# 
# - Asignar a este nuevo usuario al grupo dialout:
#
#	sudo usermod -a -G dialout nuevousuario
#
# - Copiar los directorios .mono y .Slic3r a la carpeta home del usuario en cuestión (/home/nombreusuario):
#
#	sudo cp -R /home/usuarioactual/.mono /home/usuarioactual/.Slic3r /home/nuevousuario
#
# - Asignar como dueño de dichos directorios (ya copiados en la nueva ubicación) al usuario deseado:
#
#	sudo chown -R nombreusuario /home/nombreusuario/.mono /home/nombreusuario/.Slic3r
#
# - Copiar el acceso directo "Repetier-Host.desktop" en el escritorio del nuevo usuario:
#
#	sudo cp -R /home/usuarioactual/Escritorio/Repetier-Host.desktop /home/nuevousuario/Escritorio
#
# - Asignar como dueño de dicho acceso directo nuevo al usuario deseado, con el mismo comando que antes:
#
#	sudo chown -R nuevousuario /home/nuevousuario/Escritorio/Repetier-Host.desktop
