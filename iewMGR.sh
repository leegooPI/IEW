#!/usr/bin/env bash

##-----------------------------------------------------------
## Program	: iewMGR
## Author	: Nick
## Date		: 2015-07-10
## Desc		: 游戏主控制脚本
##-----------------------------------------------------------
ulimit -c unlimited
ulimit -SHn 51200

##获取脚本执行目录
here=`which "$0" 2>/dev/null || echo .`
base="`dirname $here`"
SHELL_DIR=`(cd "$base"; echo $PWD)`

## 测试本脚本是在源码目录下还是在发布目录下
if [ -f "$SHELL_DIR/version_server.txt" ] ; then
	IN_SRC_DIR=0
else
	IN_SRC_DIR=1
fi

## erlang 节点 cookie
ERLANG_COOKIE=`cat ~/.erlang.cookie`

## 获取agent_name和server_name
AGENT_NAME=`grep "agent_name" $SHELL_DIR/./setting/common.config | awk -F"," '{print $2}' | awk -F\" '{print $2}'`
SERVER_NAME=`grep "server_name" $SHELL_DIR/./setting/common.config | awk -F"," '{print $2}' | awk -F\" '{print $2}'`

## 根目录设置
BASE_DIR="/ngdata/iew_${AGENT_NAME}_${SERVER_NAME}"
LOGS_DIR="/ngdata/logs/${AGENT_NAME}_${SERVER_NAME}"
MANAGER_LOG_FILE="${LOGS_DIR}/iew_manager.log"

CONFIG_DIR="$SHELL_DIR/config"

## 发布后的各个目录 ======= begin =============
#### -- Server根目录
SERVER_DIR="${BASE_DIR}/server"
#### -- Ebin目录设置
SERVER_EBIN="${SERVER_DIR}/ebin"
#### -- 最终config目录设置
RELEASE_CONFIG_DIR="${SERVER_DIR}/config"
#### -- 最终setting 目录
RELEASE_SETTING_DIR="${SERVER_DIR}/setting"
## 发布后的各个目录 ======= end =============

help ()
{
    echo "iewMGR 使用说明"
    echo "基本语法: iewMGR 命令模块 [option]"
    echo "命令模块："
    echo "help                  	显示当前帮助内容"
    echo "web                   	游戏管理后台相关操作"
    echo "game                  	游戏服相关操作"
    echo "game_web              	游戏服web页面相关操作"
    echo "debug                 	debug相关操作"
    echo "live                  	live相关操作"
    echo "stop                  	stop相关操作"
    echo "start                 	start相关操作"
    echo "backup iewd          	        备份游戏"
    echo "stop_gateway manager    	游戏踢人"
    echo "Receiver启动：./iewMGR start iewr 10001 [port必须大于1024]"
    echo ""
    exit 0
}

cp_file()
{
	if [ $IN_SRC_DIR ] ; then
		echo "拷贝配置及脚本文件到服务器运行目录"
		rm -rf $RELEASE_CONFIG_DIR
		mkdir -p $RELEASE_CONFIG_DIR
		mkdir -p $RELEASE_SETTING_DIR
		## 创建manager.log文件
		[ -d $LOGS_DIR/ ] || mkdir -p $LOGS_DIR/
		[ ! -f $MANAGER_LOG_FILE ] || echo '' > $MANAGER_LOG_FILE
		[ -d $SERVER_EBIN/library/ ] || mkdir -p $SERVER_EBIN/library/
		[ -d $SERVER_EBIN/proto/ ] || mkdir -p $SERVER_EBIN/proto/

		\cp -rf $SHELL_DIR/ebin/proto $SERVER_EBIN/

		rm -rf $SERVER_DIR/script/*
		mkdir -p $SERVER_DIR/script

		\cp -rf $SHELL_DIR/ebin/library/ $SERVER_EBIN/

		echo $CONFIG_DIR

		\cp -rf $CONFIG_DIR/app/* $SERVER_EBIN/
		\cp -rf $CONFIG_DIR $SERVER_DIR/

		\cp -rf $SHELL_DIR/setting $SERVER_DIR/

		\cp -rf $SHELL_DIR/iewMGR $SERVER_DIR/
		\cp -rf $SHELL_DIR/script $SERVER_DIR/

	else
        	echo "非源码目录，不能执行拷贝文件操作"
    fi
}

make_make()
{
	if [ $IN_SRC_DIR ] ; then
		echo "编译开始 ========================"
		#切换到代码根目录
		cd $SHELL_DIR
		#切换到脚本目录
		cd script
		make all
		echo "拷贝配置文件中..."
		cp_file

		echo "编译common源码中..."
	    	cd $SHELL_DIR/app/game/common/
	    	make

		cd $SHELL_DIR/app/game/manager/
		make

		cd $SHELL_DIR/app/game/behavior/
		make

		cd $SHELL_DIR/app/game/chat/
		make

		cd $SHELL_DIR/app/game/db/
		make

		cd $SHELL_DIR/app/game/gateway/
		make

		cd $SHELL_DIR/app/game/login/
		make

		cd $SHELL_DIR/app/game/map/
		make

		cd $SHELL_DIR/app/game/receiver/
		make

		cd $SHELL_DIR/app/game/security/
		make

		cd $SHELL_DIR/app/game/world/
		make

		cd $SHELL_DIR/app/game/iewweb
		make

		cd $SHELL_DIR/app/game/merge
		make

		cd $SHELL_DIR/update
	    	make

	    	if [ "$1" != "no_config" ] ; then
	       		echo '将重新编译配置文件 ----（使用 ./iewMGR make_erl命令可以避免编译配置）'
	       		cd $SHELL_DIR/script/
           		bash make_config_beam.sh
           		bash make_mission_beam.sh
        	else
           		echo '你选择了不重新编译配置文件，请确认配置木有修改----（使用 ./iewMGR make命令可以重新编译配置）'
        	fi

		##cp_file
		rm -rf $SERVER_EBIN/user_default.beam
		cp -rf $SERVER_EBIN/common/user_default.beam $SERVER_EBIN
	else
        	echo "非源码目录，不能执行make操作"
    	fi
}

make_help()
{
	echo "iewMGR game make 使用说明"
	echo "基本语法: iewMGR game make [命令]"
	echo "命令为空则为直接编译项目"
	echo "命令模块："
	echo "help 		显示当前帮助内容"
	echo "clean 	清理所有子项目编译内容"
	echo "dialyzer 	运行所有子项目的dialyzer"
	echo "debug		以debug方式编译"
	echo ""
	exit 0
}

make_clean()
{
    	if [ $IN_SRC_DIR ] ; then
		rm -f $SERVER_EBIN/config/*

		rm -f $SHELL_DIR/hrl/all_pb.hrl
		rm -f $SHELL_DIR/hrl/mm_define.hrl

		cd $SHELL_DIR/app/game/common/
		make clean

		cd $SHELL_DIR/app/game/manager/
		make clean

		cd $SHELL_DIR/app/game/behavior/
		make clean

		cd $SHELL_DIR/app/game/chat/
		make clean

		cd $SHELL_DIR/app/game/db/
		make clean

		cd $SHELL_DIR/app/game/gateway/
		make clean

		cd $SHELL_DIR/app/game/login/
		make clean

		cd $SHELL_DIR/app/game/map/
		make clean

		cd $SHELL_DIR/app/game/receiver/
		make clean

		cd $SHELL_DIR/app/game/security/
		make clean

		cd $SHELL_DIR/app/game/world/
		make clean

		cd $SHELL_DIR/app/game/merge/
		make clean

		cd $SHELL_DIR/app/game/iewweb
		make clean
	else
        	echo "非源码目录，不能执行make clean操作"
    	fi
}

make_dialyzer()
{
    	if [ $IN_SRC_DIR ] ; then
		cd $SHELL_DIR/app/game/common/
		make dialyzer

		cd $SHELL_DIR/app/game/behavior/
		make dialyzer

		cd $SHELL_DIR/app/game/chat/
		make dialyzer


		cd $SHELL_DIR/app/game/db/
		make dialyzer

		cd $SHELL_DIR/app/game/gateway/
		make dialyzer

		cd $SHELL_DIR/app/game/login/
		make dialyzer

		cd $SHELL_DIR/app/game/map/
		make dialyzer

		cd $SHELL_DIR/app/game/receiver/
		make dialyzer

		cd $SHELL_DIR/app/game/security/
		make dialyzer

		cd $SHELL_DIR/app/game/world/
		make dialyzer
	else
        	echo "非源码目录，不能执行make dialyzer操作"
    	fi
}

make_debug()
{
    	if [ $IN_SRC_DIR ] ; then
		cd $SHELL_DIR/app/game/common/
		make debug

		cd $SHELL_DIR/app/game/behavior/
		make debug

		cd $SHELL_DIR/app/game/chat/
		make debug

		cd $SHELL_DIR/app/game/db/
		make debug

		cd $SHELL_DIR/app/game/gateway/
		make debug

		cd $SHELL_DIR/app/game/login/
		make debug

		cd $SHELL_DIR/app/game/map/
		make debug

		cd $SHELL_DIR/app/game/receiver/
		make debug

		cd $SHELL_DIR/app/game/security/
		make debug

		cd $SHELL_DIR/app/game/world/
		make debug
	else
        	echo "非源码目录，不能执行make debug操作"
    	fi
}

make_map () 	{	cd $SHELL_DIR/app/game/map/ &&	make }
make_world ()	{	cd $SHELL_DIR/app/game/world/ && make }
make_login ()	{	cd $SHELL_DIR/app/game/login/ && make }
make_db ()	{	cd $SHELL_DIR/app/game/db/ && make }
make_chat () 	{	cd $SHELL_DIR/app/game/chat/ && make }
make_security() {	cd $SHELL_DIR/app/game/security/ && make}
make_erlang_web() {	cd $SHELL_DIR/app/game/iewweb/ && make}
make_common () 	{ 	cd $SHELL_DIR/app/game/common/ && make }

sub_make ()
{
	##继续检查是否还有参数，当前只识别几种参数 clean dialyzer debug
	if [ $# -ne 0 ] ; then
		MAKE_CODE=$1
		case $MAKE_CODE in
			clean) 		make_clean ;;
			dialyzer) 	make_dialyzer ;;
			debug) 		make_debug ;;
			map) 		make_map ;;
			line) 		make_line ;;
			world) 		make_world ;;
			login) 		make_login ;;
			db) 		make_db ;;
			chat) 		make_chat ;;
			security) 	make_security ;;
			erlang_web) 	make_erlang_web ;;
			common) 	make_common ;;
			*) 		make_help ;;
		esac
	else
		start=`date +%s`
		make_make
		end=`date +%s`
		dif=$[ end - start ]
		echo "make 用时   :  $dif秒"
		date +%T%n%D
	fi
}

if [ $# -eq 0 ]; then
	help
fi

game_make_erl(){
	start=`date +%s`
	make_make no_config
	end=`date +%s`
	dif=$[ end - start ]
	echo "make_erl用时   :  $dif 秒"
	date +%T%n%D
}

game_cp_file(){
    cp_file
}

game_rebuild()
{
	if [ $IN_SRC_DIR ] ; then
		start=`date +%s`
		make_clean
		make_make
		end=`date +%s`
		dif=$[ end - start ]
		echo "rebuild用时:	$dif 秒"
		date +%T%n%D
	else
		echo "非源码目录，不能执行rebuild操作"
	fi
}

game_help()
{
	echo "iewMGR game 使用说明"
	echo "基本语法: iewMGR game 命令 [option]"
	echo "命令模块："
	echo "help 		显示当前帮助内容"
	echo "make 		同make语法"
	echo "rebuild 	重新编译，相当于 make clean && make"
	echo ""
	exit 0
}

parse_game()
{
	SUB_TARGET=$1
	shift
	case $SUB_TARGET in
		help) 		game_help ;;
		make) 		sub_make $* ;;
		make_erl) 	game_make_erl ;;
		cp_file) 	game_cp_file ;;
		rebuild) 	game_rebuild ;;
		*) 		game_help ;;
	esac
}

start_app()
{
	NODE=$1
	SLAVE_NUM=$2
    COMMAND=`php $SHELL_DIR/script/host_info.php get_start_command $NODE $SLAVE_NUM; exit $?`
	if [ $? -eq 0 ] ; then
		echo "$COMMAND" >> $MANAGER_LOG_FILE
		bash -c "$COMMAND"
	else
		echo $COMMAND;
		exit
	fi
}

start_game()
{
	start=`date +%s`
	[ -d $LOGS_DIR/ ] || mkdir -p $LOGS_DIR/
    [ ! -f $MANAGER_LOG_FILE ] || echo '' > $MANAGER_LOG_FILE
	if [ $# -ne 0 ] ; then
		TARGET_NODE=$1
		SLAVE_NUM=$2
		start_app $TARGET_NODE $SLAVE_NUM
	else
		## 运行manager节点
		start_app manager
		tail -f $MANAGER_LOG_FILE
	fi
	end=`date +%s`
	dif=$[ end - start ]
	echo "游戏启动用时   :  $dif秒"
	date +%T%n%D
}

stop_all()
{
	stop_app manager
}

stop_app()
{
	NODE=$1
	COMMAND=`php $SHELL_DIR/script/host_info.php get_stop_command $NODE; exit $?`
	if [ $? -eq 0 ] ; then
		bash -c "$COMMAND"
	else
		echo $COMMAND;
		exit
	fi
}

stop_game()
{
	if [ $# -ne 0 ] ; then
		stop_app $1
	else
		stop_all
	fi
}


debug_app()
{
	NODE=$1
	REAL_IP=$2
	COMMAND=`php $SHELL_DIR/script/host_info.php get_debug_command $NODE $REAL_IP; exit $?`
	if [ $? -eq 0 ] ; then
		bash -c "$COMMAND"
	else
		echo $COMMAND;
		exit
	fi
}

debug_game()
{
	if [ $# -ne 0 ] ; then
		debug_app $1 $2
	else
		help
	fi
}

backup()
{
	NODE=$1
	COMMAND=`php $SHELL_DIR/script/host_info.php backup $NODE; exit $?`
	if [ $? -eq 0 ] ; then
		bash -c "$COMMAND"
	else
		echo $COMMAND;
		exit
	fi
}

start_gateway()
{
	NODE=$1
	COMMAND=`php $SHELL_DIR/script/host_info.php start_gateway $NODE; exit $?`
	if [ $? -eq 0 ] ; then
		bash -c "$COMMAND"
	else
		echo $COMMAND;
		exit
	fi
}

stop_gateway()
{
	NODE=$1
	COMMAND=`php $SHELL_DIR/script/host_info.php stop_gateway $NODE; exit $?`
	if [ $? -eq 0 ] ; then
		bash -c "$COMMAND"
	else
		echo $COMMAND;
		exit
	fi
}

## 重新载入配置文件
reload_config()
{
	FILE=$1
	COMMAND=`php $SHELL_DIR/script/host_info.php reload_config manager $FILE; exit $?`
	if [ $? -eq 0 ] ; then
		bash -c "$COMMAND"
	else
		echo $COMMAND;
		exit
	fi
}

hot_update()
{
	FILE=$1
	COMMAND=`php $SHELL_DIR/script/host_info.php hot_update manager $FILE; exit $?`
	if [ $? -eq 0 ] ; then
		bash -c "$COMMAND"
	else
		echo $COMMAND;
		exit
	fi
}

mnesia_update()
{
	MODULE=$1
	METHOD=$2
	COMMAND=`php $SHELL_DIR/script/host_info.php mnesia_update iewd $MODULE $METHOD; exit $?`
	if [ $? -eq 0 ] ; then
		bash -c "$COMMAND"
		result=$?
		case $result in
		0) :;;
		1) :;;
		2) help;;
		3) help;;
		4) echo "${AGENT_NAME}_${SERVER_NAME}:mnesia updating!";;
		5) echo "${AGENT_NAME}_${SERVER_NAME}:mnesia update done!";;
		6) echo "${AGENT_NAME}_${SERVER_NAME}:mnesia update error!";;
		esac
		return $result
	else
		echo $COMMAND;
		exit
	fi
}

func()
{
	FILE=$1
	COMMAND=`php $SHELL_DIR/script/host_info.php func manager $FILE $2; exit $?`
	if [ $? -eq 0 ] ; then
		bash -c "$COMMAND"
	else
		echo $COMMAND;
		exit
	fi
}

func_all()
{
	FILE=$1
	COMMAND=`php $SHELL_DIR/script/host_info.php func_all manager $FILE $2; exit $?`
	if [ $? -eq 0 ] ; then
		bash -c "$COMMAND"
	else
		echo $COMMAND;
		exit
	fi
}

## 管理功能
mananger()
{
	COMMAND=$1
	shift
	case $COMMAND in
		reload_config)	reload_config $*;;
		hot_update) 	hot_update $*;;
		mnesia_update) 	mnesia_update $*;;
		func ) 		func $*;;
		func_all ) 	func_all $*;;
		*) 		help ;;
	esac
}

#####################################################
### 第一层子命令：
#####################################################

## 获取子shell命令
TARGET=$1
shift
case $TARGET in
	help) help ;;
	web) shift ;;
	game) 		parse_game $* ;;
	make_map) 	make_map $*;;
	make) 		sub_make $* ;;
	make_erl) 	game_make_erl $* ;;
	cp_file) 	game_cp_file $* ;;
	rebuild) 	game_rebuild $* ;;
	start) 		start_game $*;;
	stop) 		stop_game $*;;
	debug) 		debug_game $*;;
	backup) 	backup $*;;
	start_gateway) 	start_gateway $*;;
	stop_gateway) 	stop_gateway $*;;
	manager) 	mananger $*;;
	*) help ;;
esac
