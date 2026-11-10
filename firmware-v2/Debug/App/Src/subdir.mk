################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (13.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../App/Src/nmea_parser.c \
../App/Src/record.c \
../App/Src/track.c 

OBJS += \
./App/Src/nmea_parser.o \
./App/Src/record.o \
./App/Src/track.o 

C_DEPS += \
./App/Src/nmea_parser.d \
./App/Src/record.d \
./App/Src/track.d 


# Each subdirectory must supply rules for building sources it contributes
App/Src/%.o App/Src/%.su App/Src/%.cyclo: ../App/Src/%.c App/Src/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m4 -std=gnu11 -g3 -DDEBUG -DUSE_HAL_DRIVER -DSTM32L475xx -c -I../Core/Inc -I../Drivers/STM32L4xx_HAL_Driver/Inc -I../Drivers/STM32L4xx_HAL_Driver/Inc/Legacy -I../Drivers/CMSIS/Device/ST/STM32L4xx/Include -I../Drivers/CMSIS/Include -I../BlueNRG_MS/Target -I../Middlewares/ST/BlueNRG-MS/utils -I../Middlewares/ST/BlueNRG-MS/includes -I../Drivers/BSP/B-L475E-IOT01A2 -I../Middlewares/ST/BlueNRG-MS/hci/hci_tl_patterns/Basic -I"C:/Users/nermi/Documents/Projects-3ISEOC/bike-tracker/firmware-v2/App/Inc" -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv4-sp-d16 -mfloat-abi=hard -mthumb -o "$@"

clean: clean-App-2f-Src

clean-App-2f-Src:
	-$(RM) ./App/Src/nmea_parser.cyclo ./App/Src/nmea_parser.d ./App/Src/nmea_parser.o ./App/Src/nmea_parser.su ./App/Src/record.cyclo ./App/Src/record.d ./App/Src/record.o ./App/Src/record.su ./App/Src/track.cyclo ./App/Src/track.d ./App/Src/track.o ./App/Src/track.su

.PHONY: clean-App-2f-Src

