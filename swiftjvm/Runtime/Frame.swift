//
//  StackFrame.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 8/2/23.
//

import Foundation

class Frame {
    let currentClass: ClassOrModuleOrPackageConstant
    let constantPool: ConstantPool
    let method: MethodInfo
    var localVariables: [LocalVariable]
    var operandStack: [AnyObject]
    
    init(classFile: ClassFile, constantPool: ConstantPool, method: MethodInfo, localVariables: [LocalVariable] = [], operandStack: [AnyObject] = []) {
        self.constantPool = constantPool
        self.localVariables = localVariables
        self.operandStack = operandStack
        self.currentClass = self.constantPool[classFile.thisClassIndex] as! ClassOrModuleOrPackageConstant
        self.method = method
        // TODO: figure out how to get the current method. might need to be passed in
    }
    func executeNextInstruction(data: Data, pc: inout Int) { // this function signature will certainly change
        let opcode = BytecodeInstruction.Opcode(rawValue: readFromData(data, cursor: &pc))!
        switch opcode {
        case .nop:
            return
//        case .aconst_null:
//            <#code#>
//        case .iconst_m1:
//            <#code#>
//        case .iconst_0:
//            <#code#>
//        case .iconst_1:
//            <#code#>
//        case .iconst_2:
//            <#code#>
//        case .iconst_3:
//            <#code#>
//        case .iconst_4:
//            <#code#>
//        case .iconst_5:
//            <#code#>
//        case .lconst_0:
//            <#code#>
//        case .lconst_1:
//            <#code#>
//        case .fconst_0:
//            <#code#>
//        case .fconst_1:
//            <#code#>
//        case .fconst_2:
//            <#code#>
//        case .dconst_0:
//            <#code#>
//        case .dconst_1:
//            <#code#>
//        case .bipush:
//            <#code#>
//        case .sipush:
//            <#code#>
//        case .ldc:
//            <#code#>
//        case .ldc_w:
//            <#code#>
//        case .ldc2_w:
//            <#code#>
//        case .iload:
//            <#code#>
//        case .lload:
//            <#code#>
//        case .fload:
//            <#code#>
//        case .dload:
//            <#code#>
//        case .aload:
//            <#code#>
//        case .iload_0:
//            <#code#>
//        case .iload_1:
//            <#code#>
//        case .iload_2:
//            <#code#>
//        case .iload_3:
//            <#code#>
//        case .lload_0:
//            <#code#>
//        case .lload_1:
//            <#code#>
//        case .lload_2:
//            <#code#>
//        case .lload_3:
//            <#code#>
//        case .fload_0:
//            <#code#>
//        case .fload_1:
//            <#code#>
//        case .fload_2:
//            <#code#>
//        case .fload_3:
//            <#code#>
//        case .dload_0:
//            <#code#>
//        case .dload_1:
//            <#code#>
//        case .dload_2:
//            <#code#>
//        case .dload_3:
//            <#code#>
//        case .aload_0:
//            <#code#>
//        case .aload_1:
//            <#code#>
//        case .aload_2:
//            <#code#>
//        case .aload_3:
//            <#code#>
//        case .iaload:
//            <#code#>
//        case .laload:
//            <#code#>
//        case .faload:
//            <#code#>
//        case .daload:
//            <#code#>
//        case .aaload:
//            <#code#>
//        case .baload:
//            <#code#>
//        case .caload:
//            <#code#>
//        case .saload:
//            <#code#>
//        case .istore:
//            <#code#>
//        case .lstore:
//            <#code#>
//        case .fstore:
//            <#code#>
//        case .dstore:
//            <#code#>
//        case .astore:
//            <#code#>
//        case .istore_0:
//            <#code#>
//        case .istore_1:
//            <#code#>
//        case .istore_2:
//            <#code#>
//        case .istore_3:
//            <#code#>
//        case .lstore_0:
//            <#code#>
//        case .lstore_1:
//            <#code#>
//        case .lstore_2:
//            <#code#>
//        case .lstore_3:
//            <#code#>
//        case .fstore_0:
//            <#code#>
//        case .fstore_1:
//            <#code#>
//        case .fstore_2:
//            <#code#>
//        case .fstore_3:
//            <#code#>
//        case .dstore_0:
//            <#code#>
//        case .dstore_1:
//            <#code#>
//        case .dstore_2:
//            <#code#>
//        case .dstore_3:
//            <#code#>
//        case .astore_0:
//            <#code#>
//        case .astore_1:
//            <#code#>
//        case .astore_2:
//            <#code#>
//        case .astore_3:
//            <#code#>
//        case .iastore:
//            <#code#>
//        case .lastore:
//            <#code#>
//        case .fastore:
//            <#code#>
//        case .dastore:
//            <#code#>
//        case .aastore:
//            <#code#>
//        case .bastore:
//            <#code#>
//        case .castore:
//            <#code#>
//        case .sastore:
//            <#code#>
//        case .pop:
//            <#code#>
//        case .pop2:
//            <#code#>
//        case .dup:
//            <#code#>
//        case .dup_x1:
//            <#code#>
//        case .dup_x2:
//            <#code#>
//        case .dup2:
//            <#code#>
//        case .dup2_x1:
//            <#code#>
//        case .dup2_x2:
//            <#code#>
//        case .swap:
//            <#code#>
//        case .iadd:
//            <#code#>
//        case .ladd:
//            <#code#>
//        case .fadd:
//            <#code#>
//        case .dadd:
//            <#code#>
//        case .isub:
//            <#code#>
//        case .lsub:
//            <#code#>
//        case .fsub:
//            <#code#>
//        case .dsub:
//            <#code#>
//        case .imul:
//            <#code#>
//        case .lmul:
//            <#code#>
//        case .fmul:
//            <#code#>
//        case .dmul:
//            <#code#>
//        case .idiv:
//            <#code#>
//        case .ldiv:
//            <#code#>
//        case .fdiv:
//            <#code#>
//        case .ddiv:
//            <#code#>
//        case .irem:
//            <#code#>
//        case .lrem:
//            <#code#>
//        case .frem:
//            <#code#>
//        case .drem:
//            <#code#>
//        case .ineg:
//            <#code#>
//        case .lneg:
//            <#code#>
//        case .fneg:
//            <#code#>
//        case .dneg:
//            <#code#>
//        case .ishl:
//            <#code#>
//        case .lshl:
//            <#code#>
//        case .ishr:
//            <#code#>
//        case .lshr:
//            <#code#>
//        case .iushr:
//            <#code#>
//        case .lushr:
//            <#code#>
//        case .iand:
//            <#code#>
//        case .land:
//            <#code#>
//        case .ior:
//            <#code#>
//        case .lor:
//            <#code#>
//        case .ixor:
//            <#code#>
//        case .lxor:
//            <#code#>
//        case .iinc:
//            <#code#>
//        case .i2l:
//            <#code#>
//        case .i2f:
//            <#code#>
//        case .i2d:
//            <#code#>
//        case .l2i:
//            <#code#>
//        case .l2f:
//            <#code#>
//        case .l2d:
//            <#code#>
//        case .f2i:
//            <#code#>
//        case .f2l:
//            <#code#>
//        case .f2d:
//            <#code#>
//        case .d2i:
//            <#code#>
//        case .d2l:
//            <#code#>
//        case .d2f:
//            <#code#>
//        case .i2b:
//            <#code#>
//        case .i2c:
//            <#code#>
//        case .i2s:
//            <#code#>
//        case .lcmp:
//            <#code#>
//        case .fcmpl:
//            <#code#>
//        case .fcmpg:
//            <#code#>
//        case .dcmpl:
//            <#code#>
//        case .dcmpg:
//            <#code#>
//        case .ifeq:
//            <#code#>
//        case .ifne:
//            <#code#>
//        case .iflt:
//            <#code#>
//        case .ifge:
//            <#code#>
//        case .ifgt:
//            <#code#>
//        case .ifle:
//            <#code#>
//        case .if_icmpeq:
//            <#code#>
//        case .if_icmpne:
//            <#code#>
//        case .if_icmplt:
//            <#code#>
//        case .if_icmpge:
//            <#code#>
//        case .if_icmpgt:
//            <#code#>
//        case .if_icmple:
//            <#code#>
//        case .if_acmpeq:
//            <#code#>
//        case .if_acmpne:
//            <#code#>
//        case .goto:
//            <#code#>
//        case .jsr:
//            <#code#>
//        case .ret:
//            <#code#>
//        case .tableswitch:
//            <#code#>
//        case .lookupswitch:
//            <#code#>
//        case .ireturn:
//            <#code#>
//        case .lreturn:
//            <#code#>
//        case .freturn:
//            <#code#>
//        case .dreturn:
//            <#code#>
//        case .areturn:
//            <#code#>
//        case .return:
//            <#code#>
//        case .getstatic:
//            <#code#>
//        case .putstatic:
//            <#code#>
//        case .getfield:
//            <#code#>
//        case .putfield:
//            <#code#>
//        case .invokevirtual:
//            <#code#>
//        case .invokespecial:
//            <#code#>
//        case .invokestatic:
//            <#code#>
//        case .invokeinterface:
//            <#code#>
//        case .invokedynamic:
//            <#code#>
        case .new:
            let hi: UInt8 = readFromData(data, cursor: &pc)
            let lo: UInt8 = readFromData(data, cursor: &pc)
            let index = UInt16(hi) << 8 | UInt16(lo)
            guard let classRef = constantPool[index] else { return } // ClassConstant
            Runtime.vm
//            operandStack.append(classRef)
//        case .newarray:
//            <#code#>
//        case .anewarray:
//            <#code#>
//        case .arraylength:
//            <#code#>
//        case .athrow:
//            <#code#>
//        case .checkcast:
//            <#code#>
//        case .instanceof:
//            <#code#>
//        case .monitorenter:
//            <#code#>
//        case .monitorexit:
//            <#code#>
//        case .wide:
//            <#code#>
//        case .multianewarray:
//            <#code#>
//        case .ifnull:
//            <#code#>
//        case .ifnonnull:
//            <#code#>
//        case .goto_w:
//            <#code#>
//        case .jsr_w:
//            <#code#>
//        case .breakpoint:
//            <#code#>
//        case .impdep1:
//            <#code#>
//        case .impdep2:
//            <#code#>
        default:
            print("got unimplemented opcode: \(opcode)")
            fatalError()
        }
        return
    }
}
