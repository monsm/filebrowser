#!/bin/sh

source /koolshare/scripts/base.sh
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
module=filebrowser
DIR=$(cd $(dirname $0); pwd)
ROG_86U=0
EXT_NU=$(nvram get extendno)
EXT_NU=${EXT_NU%_*}
odmpid=$(nvram get odmpid)
productid=$(nvram get productid)
[ -n "${odmpid}" ] && MODEL="${odmpid}" || MODEL="${productid}"
LINUX_VER=$(uname -r|awk -F"." '{print $1$2}')

# 获取固件类型
_get_type() {
  local FWTYPE=$(nvram get extendno|grep koolshare)
  if [ -d "/koolshare" ];then
    if [ -n $FWTYPE ];then
      echo "koolshare官改固件"
    else
      echo "koolshare梅林改版固件"
    fi
  else
    if [ "$(uname -o|grep Merlin)" ];then
      echo "梅林原版固件"
    else
      echo "华硕官方固件"
    fi
  fi
}

exit_install(){
  local state=$1
  case $state in
    1)
      echo_date "本插件适用于【koolshare 梅林改/官改 hnd/axhnd/axhnd.675x armsoft 384】固件平台！"
      echo_date "你的固件平台不能安装！！!"
      echo_date "如有问题请联系我们反馈相关信息 http://forum.filebrowser.com"
      echo_date "退出安装！"
      rm -rf /tmp/${module}* >/dev/null 2>&1
      exit 1
      ;;
    0|*)
      rm -rf /tmp/${module}* >/dev/null 2>&1
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

if [ "`uname -o|grep Merlin`" ] && [ -d "/koolshare" ] && [ -n "`nvram get buildno|grep -E 384\|386`" ];then
  echo_date 固件平台【koolshare merlin armv7l 384/386】符合安装要求，开始安装插件！
elif [ -d "/koolshare" -a -f "/usr/bin/skipd" -a "${LINUX_VER}" -ge "41" ];then
  # 判断路由架构和平台：koolshare固件，并且linux版本大于等于4.1
  echo_date 机型：${MODEL} $(_get_type) 符合安装要求，开始安装插件！
  install_now
else
  exit_install 1
fi
# 完成
echo_date "filebrowser 插件安装完毕！"
exit_install
