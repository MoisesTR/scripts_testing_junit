#!/bin/bash

#VARIABLES DE ENTORNO DEL PROYECTO
#MAVEN_CLI_OPTS

#NOMBRE DE LA RAMA ORIGEN DEL MERGE REQUEST
#${CI_COMMIT_REF_NAME}

origin=origin/

#ARCHIVOS MODIFICADOS ENTRE LA RAMA ORIGIN/MASTER Y LA RAMA ORIGEN QUE HIZO LA PETICION DE MERGE REQUEST
modified_java_files=$(git diff origin/master $origin${CI_COMMIT_REF_NAME} --name-only | grep ".*java$" | grep -v "Test")

#EJECUTAR LAS PRUEBAS UNITARIAS DESDE LA RAMA FEATURE_UNIT_TESTING
temporal_branch_test="rama_temporal"
if git rev-parse --quiet --verify ${temporal_branch_test}; then
  git branch -D ${temporal_branch_test}
fi

git checkout -b ${temporal_branch_test}
git merge --quiet origin/feature_unit_testing

#ARCHIVOS DE PRUEBA ENCONTRADOS BAJO LA CARPETA src/test
java_test_files=$(ls -R src/test | grep ".java$" | grep "Test")
#total_files_test=$(ls -R src/test | grep ".java$" | grep "Test" | wc -l)

#COLORES PARA LOS MENSAJES
BLUE="\033[34m"
RED="\033[31m"
NORMAL="\033[0;39m"
GREEN="\033[0;32m"

commit_msg=''
msg_test_files=''
msg_to_show=''

#INDICE UTILIZADO PARA EL MENSAJE DE LOS ARCHIVOS DE PRUEBA
index_test=0

    for java_file_modified in ${modified_java_files}
    do
        #REMOVER TODO LO QUE SE ENCUENTRE DESDE EL INICIO DEL STRING HASTA EL ULTIMO CARACTER "/"[INCLUYENDOLO]
        temp_java=${java_file_modified##*/}

        #REMOVER TODO LO QUE SE ENCUENTRE DESDE EL FINAL DEL STRING HASTA LA PRIMER COINCIDENCIA CON EL CARACTER
        # "."[INCLUYENDOLO]
        java_file_modified_without_ext=${temp_java%.*}

        for test_file in ${java_test_files}
        do
            #NOMBRE DE ARCHIVO DE PRUEBA SIN LA EXTENSION .JAVA
            test_file_without_ext=${test_file%.*}
            test_file_without_ext_comparison=${test_file_without_ext}

            #REMOVER TEXTO DESDE FINAL HASTA QUE ENCUENTRE LA PRIMER COINCIDENCIA CON Parameterized
            if [[ ${test_file_without_ext_comparison} == *"Parameterized"* ]]; then
              test_file_without_ext_comparison=${test_file_without_ext_comparison%Parameterized*}
            fi

            #REMOVER TEXTO DESDE EL FINAL HASTA QUE ENCUENTRE LA PRIMER COINCIDENCIA CON Mock
            if [[ ${test_file_without_ext_comparison} == *"Mock"* ]]; then
              test_file_without_ext_comparison=${test_file_without_ext_comparison%Mock*}
            fi

            #REMOVER TEXTO DESDE EL FINAL HASTA QUE ENCUENTRE LA PRIMER COINCIDENCIA CON Test
            if [[ ${test_file_without_ext_comparison} == *"Test"* ]]; then
              test_file_without_ext_comparison=${test_file_without_ext_comparison%Test*}
            fi

            #VERIFICANDO SI EL NOMBRE DE LA CLASE MODIFICADA Y EL NOMBRE DE LA PRUEBA SON IGUALES
            if [[ ${java_file_modified_without_ext} == ${test_file_without_ext_comparison} ]]; then
                (( index_test++ ))
                msg_test_files+="${test_file_without_ext},"
                msg_to_show+="${index_test}- ${test_file_without_ext}\n "
            fi
        done
    done

    if [[ -z ${msg_test_files} ]]; then
        echo -e ${RED} "No se encontraron pruebas para ejecutar!" ${NORMAL}
    else

        echo -e "================================================================\n"
        echo -e "CLASES DE PRUEBA:\n"
        echo -e ${GREEN} ${msg_to_show} ${NORMAL}
        echo -e "================================================================\n"
        commit_msg=-Dtest=${msg_test_files}
        
        #EJECUTANDO PRUEBAS UNITARIAS
        mvn $MAVEN_CLI_OPTS test ${commit_msg} test
    fi
