#!/bin/sh
source /koolshare/scripts/base.sh
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
MODEL=
FW_TYPE_CODE=
FW_TYPE_NAME=
DIR=$(cd $(dirname $0); pwd)
module=${DIR##*/}

get_model(){
	local ODMPID=$(nvram get odmpid)
	local PRODUCTID=$(nvram get productid)
	if [ -n "${ODMPID}" ];then
		MODEL="${ODMPID}"
	else
		MODEL="${PRODUCTID}"
	fi
}

get_fw_type() {
	local KS_TAG=$(nvram get extendno|grep -Eo "kool.+")
	if [ -d "/koolshare" ];then
		if [ -n "${KS_TAG}" ];then
			FW_TYPE_CODE="2"
			FW_TYPE_NAME="${KS_TAG}官改固件"
		else
			FW_TYPE_CODE="4"
			FW_TYPE_NAME="koolshare梅林改版固件"
		fi
	else
		if [ "$(uname -o|grep Merlin)" ];then
			FW_TYPE_CODE="3"
			FW_TYPE_NAME="梅林原版固件"
		else
			FW_TYPE_CODE="1"
			FW_TYPE_NAME="华硕官方固件"
		fi
	fi
}

platform_test(){
	local LINUX_VER=$(uname -r|awk -F"." '{print $1$2}')
	local ARCH=$(uname -m)
	if [ -d "/koolshare" -a -f "/usr/bin/skipd" -a "${LINUX_VER}" -ge "41" ];then
		if [ "${ARCH}" != "aarch64" ];then
			exit_install 2
		else
			echo_date 机型："${MODEL} ${FW_TYPE_NAME} 符合安装要求，开始安装插件！"
		fi
	else
		exit_install 1
	fi
}

set_skin(){
	local UI_TYPE=ASUSWRT
	local SC_SKIN=$(nvram get sc_skin)
	local ROG_FLAG=$(grep -o "680516" /www/form_style.css|head -n1)
	local TUF_FLAG=$(grep -o "D0982C" /www/form_style.css|head -n1)
	if [ -n "${ROG_FLAG}" ];then
		UI_TYPE="ROG"
	fi
	if [ -n "${TUF_FLAG}" ];then
		UI_TYPE="TUF"
	fi
	
	if [ -z "${SC_SKIN}" -o "${SC_SKIN}" != "${UI_TYPE}" ];then
		echo_date "安装${UI_TYPE}皮肤！"
		nvram set sc_skin="${UI_TYPE}"
		nvram commit
	fi
}

exit_install(){
	local state=$1
	case $state in
		1)
			echo_date "本插件适用于【koolshare 梅林改/官改 hnd/axhnd/axhnd.675x】固件平台！"
			echo_date "你的固件平台不能安装！！!"
			echo_date "本插件支持机型/平台：https://github.com/koolshare/rogsoft#rogsoft"
			echo_date "退出安装！"
			rm -rf /tmp/filebrowser* >/dev/null 2>&1
			exit 1
			;;
		0|*)
			rm -rf /tmp/filebrowser* >/dev/null 2>&1
			exit 0
			;;
	esac
}

dbus_nset(){
	# set key when value not exist
	local ret=$(dbus get $1)
	if [ -z "${ret}" ];then
		dbus set $1=$2
	fi
}

install_now() {
	# default value
	local TITLE="FileBrowser"
	local DESCR="FileBrowser：您的可视化路由文件管理系统"
	local PLVER=$(cat ${DIR}/version)

	# delete crontabs job first
	if [ -n "$(cru l | grep filebrowser_watchdog)" ]; then
		echo_date "删除filebrowser看门狗任务..."
		sed -i '/filebrowser_watchdog/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi
	if [ -n "$(cru l | grep filebrowser_backupdb)" ]; then
		echo_date "删除filebrowser数据库备份任务..."
		sed -i '/filebrowser_backupdb/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
	fi

	# stop signdog
	local fb_enable=$(dbus get filebrowser_enable)
	local fb_process=$(pidof filebrowser)
	if [ "${fb_enable}" == "1" -o -n "${fb_process}" ];then
		local enable="1"
		dbus set filebrowser_enable="1"
		echo_date "先关闭filebrowser插件！以保证更新成功！"
		killall filebrowser >/dev/null 2>&1
	fi

	# migrate db
	mkdir -p /koolshare/configs/filebrowser
	local dbfile_tmp=/tmp/filebrowser/filebrowser.db
	local dbfile_new=/koolshare/configs/filebrowser/filebrowser.db
	if [ -f "${dbfile_tmp}" -a ! -f "${dbfile_new}" ];then
		cp -rf ${dbfile_tmp} ${dbfile_new}
	fi
	
	# remove some files first, old file should be removed, too
	find /koolshare/init.d/ -name "*filebrowser*" | xargs rm -rf
	rm -rf /koolshare/scripts/filebrowser*.sh 2>/dev/null
	rm -rf /koolshare/scripts/*filebrowser.sh 2>/dev/null
	rm -rf /koolshare/filebrowser 2>/dev/null
	rm -rf /koolshare/bin/filebrowser 2>/dev/null
	rm -rf /koolshare/bin/filebrowser.db 2>/dev/null

	# remove old value
	dbus remove filebrowser_delay_time
	dbus remove filebrowser_version_local

	# isntall file
	echo_date "安装插件相关文件..."
	cp -rf /tmp/${module}/bin/* /koolshare/bin/
	cp -rf /tmp/${module}/res/* /koolshare/res/
	cp -rf /tmp/${module}/scripts/* /koolshare/scripts/
	cp -rf /tmp/${module}/webs/* /koolshare/webs/
	cp -rf /tmp/${module}/uninstall.sh /koolshare/scripts/uninstall_${module}.sh
	
	#创建开机自启任务
	[ ! -L "/koolshare/init.d/S99filebrowser.sh" ] && ln -sf /koolshare/scripts/filebrowser_config.sh /koolshare/init.d/S99filebrowser.sh
	[ ! -L "/koolshare/init.d/N99filebrowser.sh" ] && ln -sf /koolshare/scripts/filebrowser_config.sh /koolshare/init.d/N99filebrowser.sh

	# Permissions
	chmod +x /koolshare/scripts/filebrowser* >/dev/null 2>&1
	chmod +x /koolshare/bin/filebrowser >/dev/null 2>&1

	# dbus value
	echo_date "设置插件默认参数..."
	dbus set ${module}_version="${PLVER}"
	dbus set softcenter_module_${module}_version="${PLVER}"
	dbus set softcenter_module_${module}_install="1"
	dbus set softcenter_module_${module}_name="${module}"
	dbus set softcenter_module_${module}_title="${TITLE}"
	dbus set softcenter_module_${module}_description="${DESCR}"

	# 检查插件默认dbus值
	dbus_nset filebrowser_watchdog "0"
	dbus_nset filebrowser_port "26789"
	dbus_nset filebrowser_cert_file "/etc/cert.pem"
	dbus_nset filebrowser_key_file "/etc/key.pem"

	# re_enable
	if [ "${enable}" == "1" ];then
		echo_date "重新启动filebrowser插件！"
		sh /koolshare/scripts/filebrowser_config.sh boot_up
	fi

	# finish
	echo_date "${TITLE}插件安装完毕！"
	exit_install
}

install() {
  get_model
  get_fw_type
  #platform_test
  install_now
}

install
