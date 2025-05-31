FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Set up environment variables
ENV DISPLAY=:1
ENV VNC_PORT=5901
ENV NO_VNC_PORT=6080
ENV RDP_PORT=3389
ENV VNC_PASSWORD=vncpass
ENV USER=ubuntu
ENV PASSWORD=ubuntu

# Update system and install essential packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Desktop environment (GNOME)
    ubuntu-desktop-minimal \
    gnome-session \
    gnome-terminal \
    nautilus \
    firefox \
    # VNC server
    tightvncserver \
    # NoVNC for web access
    novnc \
    websockify \
    # XRDP for RDP access
    xrdp \
    # Additional utilities
    wget \
    curl \
    nano \
    vim \
    git \
    htop \
    net-tools \
    sudo \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    # Audio support
    pulseaudio \
    pavucontrol \
    # File manager and basic apps
    gedit \
    calculator \
    # Fonts
    fonts-liberation \
    fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

# Create user and set up sudo
RUN useradd -m -s /bin/bash $USER && \
    echo "$USER:$PASSWORD" | chpasswd && \
    usermod -aG sudo $USER && \
    echo "$USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set up VNC directory and password
RUN mkdir -p /home/$USER/.vnc && \
    echo $VNC_PASSWORD | vncpasswd -f > /home/$USER/.vnc/passwd && \
    chmod 600 /home/$USER/.vnc/passwd && \
    chown -R $USER:$USER /home/$USER/.vnc

# Configure VNC startup script
RUN echo '#!/bin/bash\n\
xrdb $HOME/.Xresources\n\
xsetroot -solid grey\n\
export XKL_XMODMAP_DISABLE=1\n\
export XDG_CURRENT_DESKTOP="GNOME"\n\
export XDG_SESSION_DESKTOP="gnome"\n\
export XDG_SESSION_TYPE="x11"\n\
export GNOME_SHELL_SESSION_MODE="ubuntu"\n\
gnome-session --session=ubuntu &\n\
gnome-panel &\n\
nautilus &\n\
gnome-terminal &\n' > /home/$USER/.vnc/xstartup && \
    chmod +x /home/$USER/.vnc/xstartup && \
    chown $USER:$USER /home/$USER/.vnc/xstartup

# Configure XRDP
RUN echo "gnome-session --session=ubuntu" > /home/$USER/.xsession && \
    chown $USER:$USER /home/$USER/.xsession && \
    chmod +x /home/$USER/.xsession

# Configure XRDP to use the correct session
RUN sed -i 's/port=3389/port=3389/g' /etc/xrdp/xrdp.ini && \
    sed -i 's/max_bpp=32/max_bpp=128/g' /etc/xrdp/xrdp.ini && \
    sed -i 's/xserverbpp=24/xserverbpp=128/g' /etc/xrdp/xrdp.ini && \
    echo "gnome-session --session=ubuntu" > /etc/xrdp/startwm.sh && \
    chmod +x /etc/xrdp/startwm.sh

# Set up NoVNC
RUN mkdir -p /opt/novnc && \
    wget -qO- https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz | tar xz --strip 1 -C /opt/novnc && \
    ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# Create startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "🚀 Starting Ubuntu Desktop Environment..."\n\
\n\
# Start dbus\n\
service dbus start\n\
\n\
# Start PulseAudio\n\
runuser -l $USER -c "pulseaudio --start --log-target=syslog" || true\n\
\n\
# Start VNC server\n\
echo "🖥️ Starting VNC server on display $DISPLAY"\n\
runuser -l $USER -c "vncserver $DISPLAY -geometry 1920x1080 -depth 24"\n\
\n\
# Start XRDP\n\
echo "🔌 Starting XRDP server on port $RDP_PORT"\n\
service xrdp start\n\
\n\
# Start NoVNC\n\
echo "🌐 Starting NoVNC web server on port $NO_VNC_PORT"\n\
websockify --web /opt/novnc $NO_VNC_PORT localhost:$VNC_PORT &\n\
\n\
# Wait a moment for services to start\n\
sleep 5\n\
\n\
echo "════════════════════════════════════════════════════════"\n\
echo "🎉 Ubuntu Desktop is ready!"\n\
echo ""\n\
echo "🌐 Web Access (NoVNC): http://localhost:6080"\n\
echo "   - Click '\''Connect'\'' and enter password: $VNC_PASSWORD"\n\
echo ""\n\
echo "🖥️ RDP Access: localhost:3389"\n\
echo "   - Username: $USER"\n\
echo "   - Password: $PASSWORD"\n\
echo ""\n\
echo "🔧 VNC Direct: localhost:$VNC_PORT"\n\
echo "   - Password: $VNC_PASSWORD"\n\
echo "════════════════════════════════════════════════════════"\n\
\n\
# Keep container running\n\
tail -f /dev/null\n' > /start.sh && chmod +x /start.sh

# Create directory for user data persistence
RUN mkdir -p /home/$USER/Desktop /home/$USER/Documents /home/$USER/Downloads && \
    chown -R $USER:$USER /home/$USER

# Set proper permissions
RUN chown -R $USER:$USER /home/$USER

# Expose ports
EXPOSE 6080 3389 5901

# Create volumes for persistence
VOLUME ["/home/$USER"]

# Start the services
CMD ["/start.sh"]
