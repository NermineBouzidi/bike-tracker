################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (13.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../App/Src/app_log.c \
../App/Src/ble_service.c \
../App/Src/hist_proto.c \
../App/Src/hist_stream.c \
../App/Src/nmea_parser.c \
../App/Src/power.c \
../App/Src/record.c \
../App/Src/rtc_time.c \
../App/Src/sd_log.c \
../App/Src/sd_spi.c \
../App/Src/timeutil.c \
../App/Src/track.c 

OBJS += \
./App/Src/app_log.o \
./App/Src/ble_service.o \
./App/Src/hist_proto.o \
./App/Src/hist_stream.o \
./App/Src/nmea_parser.o \
./App/Src/power.o \
./App/Src/record.o \
./App/Src/rtc_time.o \
./App/Src/sd_log.o \
./App/Src/sd_spi.o \
./App/Src/timeutil.o \
./App/Src/track.o 

C_DEPS += \
./App/Src/app_log.d \
./App/Src/ble_service.d \
./App/Src/hist_proto.d \
./App/Src/hist_stream.d \
./App/Src/nmea_parser.d \
./App/Src/power.d \
./App/Src/record.d \
./App/Src/rtc_time.d \
./App/Src/sd_log.d \
./App/Src/sd_spi.d \
./App/Src/timeutil.d \
./App/Src/track.d 


# Each subdirectory must supply rules for building sources it contributes
App/Src/%.o App/Src/%.su App/Src/%.cyclo: ../App/Src/%.c App/Src/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m4 -std=gnu11 -g3 -DDEBUG -DUSE_HAL_DRIVER -DSTM32L475xx -c -I../Core/Inc -I../Drivers/STM32L4xx_HAL_Driver/Inc -I../Drivers/STM32L4xx_HAL_Driver/Inc/Legacy -I../Drivers/CMSIS/Device/ST/STM32L4xx/Include -I../Drivers/CMSIS/Include -I../App/Inc -I../BlueNRG_MS/Target -I../Middlewares/ST/BlueNRG-MS/utils -I../Middlewares/ST/BlueNRG-MS/includes -I../Drivers/BSP/B-L475E-IOT01A2 -I../Middlewares/ST/BlueNRG-MS/hci/hci_tl_patterns/Basic -I../FATFS/Target -I../FATFS/App -I../Middlewares/Third_Party/FatFs/src -I../Middlewares/Third_Party/FreeRTOS/Source/include -I../Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS_V2 -I../Middlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM4F -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv4-sp-d16 -mfloat-abi=hard -mthumb -o "$@"

clean: clean-App-2f-Src

clean-App-2f-Src:
	-$(RM) ./App/Src/app_log.cyclo ./App/Src/app_log.d ./App/Src/app_log.o ./App/Src/app_log.su ./App/Src/ble_service.cyclo ./App/Src/ble_service.d ./App/Src/ble_service.o ./App/Src/ble_service.su ./App/Src/hist_proto.cyclo ./App/Src/hist_proto.d ./App/Src/hist_proto.o ./App/Src/hist_proto.su ./App/Src/hist_stream.cyclo ./App/Src/hist_stream.d ./App/Src/hist_stream.o ./App/Src/hist_stream.su ./App/Src/nmea_parser.cyclo ./App/Src/nmea_parser.d ./App/Src/nmea_parser.o ./App/Src/nmea_parser.su ./App/Src/power.cyclo ./App/Src/power.d ./App/Src/power.o ./App/Src/power.su ./App/Src/record.cyclo ./App/Src/record.d ./App/Src/record.o ./App/Src/record.su ./App/Src/rtc_time.cyclo ./App/Src/rtc_time.d ./App/Src/rtc_time.o ./App/Src/rtc_time.su ./App/Src/sd_log.cyclo ./App/Src/sd_log.d ./App/Src/sd_log.o ./App/Src/sd_log.su ./App/Src/sd_spi.cyclo ./App/Src/sd_spi.d ./App/Src/sd_spi.o ./App/Src/sd_spi.su ./App/Src/timeutil.cyclo ./App/Src/timeutil.d ./App/Src/timeutil.o ./App/Src/timeutil.su ./App/Src/track.cyclo ./App/Src/track.d ./App/Src/track.o ./App/Src/track.su

.PHONY: clean-App-2f-Src

