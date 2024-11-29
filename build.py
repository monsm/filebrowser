#!/usr/bin/env python
# _*_ coding:utf-8 _*_

import os
import json
import codecs
import hashlib
from string import Template

parent_path = os.path.dirname(os.path.realpath(__file__))


def md5sum(full_path):
    with open(full_path, 'rb') as rf:
        return hashlib.md5(rf.read()).hexdigest()


def get_or_create():
    conf_path = os.path.join(parent_path, "config.json.js")
    conf = {}
    if not os.path.isfile(conf_path):
        print("config.json.js not found，build.py is root path. auto write config.json.js")
        module_name = os.path.basename(parent_path)
        conf["module"] = module_name
        conf["version"] = "0.0.1"
        conf["home_url"] = "Module_{}.asp".format(module_name)
        conf["title"] = "title of " + module_name
        conf["description"] = "description of " + module_name
    else:
        with codecs.open(conf_path, "r", "utf-8") as fc:
            conf = json.loads(fc.read())
    return conf


def build_module():
    try:
        conf = get_or_create()
    except:
        print("config.json.js file format is incorrect")
        import traceback
        traceback.print_exc()
        return  # 如果配置文件读取出现异常，直接返回，不再继续后续构建流程

    if "module" not in conf:
        print(" module is not in config.json.js")
        return
    module_path = os.path.join(parent_path, conf["module"])
    if not os.path.isdir(module_path):
        print("not found {} dir，check config.json.js is module?".format(module_path))
        return
    install_path = os.path.join(parent_path, conf["module"], "install.sh")
    if not os.path.isfile(install_path):
        print("not found {} file，check install.sh file".format(install_path))
        return

    print("build...")

    version_file_path = os.path.join(parent_path, conf["module"], "version")
    print(f"Going to write version file to: {version_file_path}")
    try:
        with open(os.path.join(parent_path, conf["module"], "version"), "w", encoding='utf-8') as f:
            f.write(conf["version"])
    except IOError as e:
        print(f"Error writing version file: {e}")
        return  # 如果版本文件写入出现错误，直接返回，停止构建

    module_name = conf["module"]
    print(f"Current module name for packing: {module_name}")
    print(f"Parent path for packing: {parent_path}")
    t = Template("cd $parent_path && rm -f $module.tar.gz && tar -zcf $module.tar.gz $module")
    command = t.substitute({"parent_path": parent_path, "module": conf["module"]})
    print(f"Packing command: {command}")
    try:
        os.system(command)
        # 检查打包文件是否真正生成成功
        tar_file_path = os.path.join(parent_path, conf["module"] + ".tar.gz")
        if not os.path.isfile(tar_file_path):
            print(f"Error: {tar_file_path} was not generated successfully.")
            return  # 如果打包文件没生成，直接返回，停止构建
    except OSError as e:
        print(f"Error executing packing command: {e}")
        return  # 如果执行打包命令出现异常，直接返回，停止构建

    print(f"Going to calculate MD5 for file: {tar_file_path}")
    try:
        conf["md5"] = md5sum(os.path.join(parent_path, conf["module"] + ".tar.gz"))
    except FileNotFoundError as e:
        print(f"Error calculating MD5: File not found - {e}")
        return  # 如果计算MD5时找不到文件，直接返回，停止构建

    conf_path = os.path.join(parent_path, "config.json.js")
    with codecs.open(conf_path, "w", encoding='utf-8') as fw:
        json.dump(conf, fw, sort_keys=True, indent=4, ensure_ascii=False)
    print("build done", conf["module"] + ".tar.gz")
    # hook_path = os.path.join(parent_path, "backup.sh")
    # if os.path.isfile(hook_path):
    #    os.system(hook_path)


if __name__ == "__main__":
    build_module()
