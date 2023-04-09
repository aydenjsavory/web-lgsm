import os
import re
import sys
import subprocess
import shutil
from flask import Blueprint, render_template, request, flash, url_for, redirect, Response
from flask_login import login_required, current_user
from werkzeug.security import generate_password_hash
from .models import *
from . import db
from .utils import *
import configparser

views = Blueprint("views", __name__)

######### Home Page #########

@views.route("/", methods=['GET'])
@views.route("/home", methods=['GET'])
@login_required
def home():
    print(os.getcwd())
    # Import meta data.
    meta_data = MetaData.query.get(1)
    base_dir = meta_data.app_install_path

    # Import config data.
    config = configparser.ConfigParser()
    config.read(f'{base_dir}/main.conf')

    servers = GameServer.query.all()
    server_names = []

    for server in servers:
        server_names.append(server.install_name)

    return render_template("home.html", user=current_user, installed_servers=server_names)


######### Controls Page #########

@views.route("/controls", methods=['GET'])
@login_required
def controls():
    # Import meta data.
    meta_data = MetaData.query.get(1)
    base_dir = meta_data.app_install_path

    # Import config data.
    config = configparser.ConfigParser()
    config.read(f'{base_dir}/main.conf')
    text_color = config['aesthetic']['text_color']

    server_name = request.args.get("server")
    script_arg = request.args.get("command")

    ## For Debug Logging.
    print("##### /controls route GET")
    if server_name != None:
        print("Server Name: " + server_name)
    if script_arg != None:
        print("Script Arg: " + script_arg)

    if server_name == None:
        flash("Error, no server specified!", category="error")
        return redirect(url_for('views.home'))

    server = GameServer.query.filter_by(install_name=server_name).first()
    if server == None:
        flash("Error loading page!", category="error")
        return redirect(url_for('views.home'))

    script_path = server.install_path + '/' + server.script_name

    if script_arg != None:
        if is_invalid_command(script_arg):
            return render_template('no_output.html', user=current_user, text_color=text_color, invalid_cmd=True)

        # Console option, use tmux capture-pane.
        if script_arg == "c":
            cmd = f'/usr/bin/tmux capture-pane -pS -5 -t {server.script_name}'
            return Response(read_process(server.install_path, base_dir, cmd, text_color, ""), mimetype= 'text/html')

        else:
            cmd = f'{script_path} {script_arg}'
            return Response(read_process(server.install_path, base_dir, cmd, text_color, ""), mimetype= 'text/html')
       
    return render_template("controls.html", user=current_user, server_name=server_name, \
                server_commands=get_commands(), text_color=text_color)

######### Iframe Default Page #########

@views.route("/no_output", methods=['GET'])
@login_required
def no_output():
    # Import meta data.
    meta_data = MetaData.query.get(1)
    base_dir = meta_data.app_install_path

    # Import config data.
    config = configparser.ConfigParser()
    config.read(f'{base_dir}/main.conf')
    text_color = config['aesthetic']['text_color']

    return render_template("no_output.html", user=current_user, text_color=text_color)

######### Install Page #########

@views.route("/install", methods=['GET', 'POST'])
@login_required
def install():
    # Import meta data.
    meta_data = MetaData.query.get(1)
    base_dir = meta_data.app_install_path

    # Import config data.
    config = configparser.ConfigParser()
    config.read(f'{base_dir}/main.conf')
    text_color = config['aesthetic']['text_color']

    ## Make its own function / find better solution.
    # Check for / install the main linuxgsm.sh script. 
    lgsmsh = "linuxgsm.sh"
    check_and_get_lgsmsh(f"{base_dir}/{lgsmsh}")

    if request.method == 'POST':
        server_script_name = request.form.get("server_name")
        server_full_name = request.form.get("full_name")
        sudo_pass = request.form.get("sudo_pass")

        # Make sure required options are supplied.
        if server_script_name == None or server_full_name == None or sudo_pass == None:
            flash("Missing Required Form Feild!", category="error")
            return redirect(url_for('views.install'))

        # Validate form submission data against install list in json file.
        if install_options_are_invalid(server_script_name, server_full_name):
            flash("Invalid Installation Option(s)!", category="error")
            return redirect(url_for('views.install'))

        # For debug info.
        print("#### IS POST ON /install")
        print("Server Script Name: " + server_script_name)
        print("Server Full Name: " + server_full_name)
            
        # Make server_full_name a unix friendly directory name.
        server_full_name = server_full_name.replace(" ", "_")

        install_name_exists = GameServer.query.filter_by(install_name=server_full_name).first()

        if install_name_exists:
            flash('An installation by that name already exits.', category='error')
            return redirect(url_for('views.install'))
        elif os.path.exists(server_full_name):
            flash('Install directory already exists.', category='error')
            flash('Did you perhaps have this server installed previously?', category='error')
            return redirect(url_for('views.install'))

        if get_tty_ticket(sudo_pass) == False:
            flash('Problem with sudo password!', category='error')
            return redirect(url_for('views.install'))
        
        # Make a new server dir and copy linuxgsm.sh into it then cd into it.
        os.mkdir(server_full_name)
        shutil.copy(lgsmsh, server_full_name)

        install_path = base_dir + '/' + server_full_name

        # Add the install to the database.
        new_game_server = GameServer(install_name=server_full_name, \
                install_path=install_path, script_name=server_script_name) 
        db.session.add(new_game_server)
        db.session.commit()
        
        setup_cmd = f'./{lgsmsh} {server_script_name} ; ./{server_script_name} ai'

        # Only flashes after install redirect to home page.
        flash("Game server added!")

        return Response(read_process(install_path, base_dir, setup_cmd, \
                        text_color, "install"), mimetype= 'text/html')

    return render_template("install.html", user=current_user, \
        servers=get_servers(), text_color=text_color)

######### Settings Page #########

@views.route("/settings", methods=['GET', 'POST'])
@login_required
def settings():
    # Import meta data.
    meta_data = MetaData.query.get(1)
    base_dir = meta_data.app_install_path

    # Import config data.
    config = configparser.ConfigParser()
    config.read(f'{base_dir}/main.conf')
    text_color = config['aesthetic']['text_color']
    remove_files = config['settings'].getboolean('remove_files')

    if request.method == 'POST':
        color_pref = request.form.get("text_color")
        file_pref = request.form.get("delete_files")

        config['settings']['remove_files'] = 'yes'
        if file_pref == "false":
            config['settings']['remove_files'] = 'no'
        
        config['aesthetic']['text_color'] = text_color
        if color_pref != None:
            # Validate color code with regular expression.
            if not re.search('^#(?:[0-9a-fA-F]{1,2}){3}$', color_pref):
                flash('Invalid color!', category='error')
                return redirect(url_for('views.settings'))

            config['aesthetic']['text_color'] = color_pref

        with open(f'{base_dir}/main.conf', 'w') as configfile:
             config.write(configfile)

        flash("Settings Updated!")
        return redirect(url_for('views.settings'))
    
    return render_template("settings.html", user=current_user, \
                text_color=text_color, remove_files=remove_files)

######### Add Page #########

@views.route("/add", methods=['GET', 'POST'])
@login_required
def add():

    if request.method == 'POST':
        install_name = request.form.get("install_name").replace(" ", "_")
        install_path = request.form.get("install_path")
        script_name = request.form.get("script_name")

        install_name_exists = GameServer.query.filter_by(install_name=install_name).first()

        for input_item in (install_name, install_path, script_name):
            if contains_bad_chars(input_item):
                flash("Illegal Character Entered", category="error")
                flash("Bad Chars: $ ' \" \ # = [ ] ! < > | ; { } ( ) * , ? ~ &", category="error")
                return redirect(url_for('views.add'))

        if install_name_exists:
            flash('An installation by that name already exits.', category='error')
        elif not os.path.exists(install_path) or not os.path.isdir(install_path):
            flash('Directory path does not exist.', category='error')
        elif not os.path.exists(install_path + '/' + script_name) or \
                not os.path.isfile(install_path + '/' + script_name):
            flash('Script file does not exist.', category='error')
        else:
            # Add the install to the database, then redirect home.
            new_game_server = GameServer(install_name=install_name, \
                        install_path=install_path, script_name=script_name) 
            db.session.add(new_game_server)
            db.session.commit()

            flash('Game server added!')
            return redirect(url_for('views.home'))
    
    return render_template("add.html", user=current_user)

# Does the actual deletions for the /delete route.
def del_server(server, remove_files):
    install_path = server.install_path 
    server_name = server.install_name

    GameServer.query.filter_by(install_name=server_name).delete()
    db.session.commit()

    if remove_files:
        if os.path.isdir(install_path):
            shutil.rmtree(install_path)
    
    flash(f'Game server, {server_name} deleted!')
    return

######### Delete Route #########

@views.route("/delete", methods=['GET', 'POST'])
@login_required
def delete():
    # Import meta data.
    meta_data = MetaData.query.get(1)
    base_dir = meta_data.app_install_path

    # Import config data.
    config = configparser.ConfigParser()
    config.read(f'{base_dir}/main.conf')
    remove_files = config['settings'].getboolean('remove_files')

    # Delete via POST is for multiple deletions, from toggles on home page.
    if request.method == 'POST':
        for server_id, server_name in request.form.items():
            server = GameServer.query.filter_by(install_name=server_name).first()
            if server != None:
                del_server(server, remove_files)
    else:
        server_name = request.args.get("server")
        if server_name == None:
            flash("Missing Required Args!", category=error)
            return redirect(url_for('views.home'))

        server = GameServer.query.filter_by(install_name=server_name).first()
        if server != None:
            del_server(server, remove_files)

    return redirect(url_for('views.home'))
