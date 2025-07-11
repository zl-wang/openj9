/*******************************************************************************
 * Copyright IBM Corp. and others 1991
 *
 * This program and the accompanying materials are made available under
 * the terms of the Eclipse Public License 2.0 which accompanies this
 * distribution and is available at https://www.eclipse.org/legal/epl-2.0/
 * or the Apache License, Version 2.0 which accompanies this distribution and
 * is available at https://www.apache.org/licenses/LICENSE-2.0.
 *
 * This Source Code may also be made available under the following
 * Secondary Licenses when the conditions for such availability set
 * forth in the Eclipse Public License, v. 2.0 are satisfied: GNU
 * General Public License, version 2 with the GNU Classpath
 * Exception [1] and GNU General Public License, version 2 with the
 * OpenJDK Assembly Exception [2].
 *
 * [1] https://www.gnu.org/software/classpath/license.html
 * [2] https://openjdk.org/legal/assembly-exception.html
 *
 * SPDX-License-Identifier: EPL-2.0 OR Apache-2.0 OR GPL-2.0-only WITH Classpath-exception-2.0 OR GPL-2.0-only WITH OpenJDK-assembly-exception-1.0
 *******************************************************************************/

/**
 * @file
 * @ingroup GC_Base
 */

#if !defined(CLASSMODEL_HPP_)
#define CLASSMODEL_HPP_

#include "j9.h"
#include "j9cfg.h"
#include "j9consts.h"
#include "modron.h"

#include "Bits.hpp"

/**
 * Provides information for a given class.
 * @ingroup GC_Base
 */
class GC_ClassModel
{
public:
	/**
	 * Returns the depth of a class.
	 * @param clazzPtr Pointer to the class whose depth is required
	 * @return Depth of class
	 */	
	MMINLINE static UDATA getClassDepth(J9Class *clazzPtr)
	{
		return J9CLASS_DEPTH(clazzPtr);
	}

	/**
	 * Returns the superclass of a class.
	 * @param clazzPtr Pointer to the class whose superclass is required
	 * @return superclass of class
	 */	
	MMINLINE static J9Class *getSuperclass(J9Class *clazzPtr)
	{
		UDATA classDepth = J9CLASS_DEPTH(clazzPtr);
		return clazzPtr->superclasses[classDepth - 1];
	}

	/**
	 * Returns TRUE if the class is an array class, FALSE otherwise.
	 * @param clazzPtr Pointer to the class
	 * @return TRUE if the class is an array class, FALSE otherwise
	 */
	MMINLINE static bool usesSharedITable(J9JavaVM *javaVM, J9Class *clazzPtr)
	{
		return (clazzPtr->romClass->modifiers & J9AccClassArray) && (clazzPtr != javaVM->booleanArrayClass);
	}

	/**
	 * Returns the size, in bytes, of an instance of a class.
	 * @param clazzPtr Pointer to the class whose instance size is required
	 * @return The size of and instance of the class in bytes
	 */
	MMINLINE static UDATA getInstanceSizeInBytes(J9Class *clazzPtr)
	{
		return clazzPtr->totalInstanceSize;
	}

	/**
	 * Calculate the number of object slots in the class.
	 * @param[in] clazz Pointer to the class
	 * @param[in] vm The J9JavaVM
	 * @return number of object slots.
	 */
	MMINLINE static UDATA
	getNumberOfObjectSlots(J9Class *clazz, J9JavaVM *vm)
	{
		UDATA totalInstanceSize = clazz->totalInstanceSize;
		IDATA scanLimit = (IDATA) (totalInstanceSize / J9JAVAVM_REFERENCE_SIZE(vm));
		UDATA tempDescription = (UDATA)clazz->instanceDescription;

		UDATA slotCount = 0;
		if (scanLimit > 0) {
			if (tempDescription & 1) {
				/* immediate */
				UDATA description = (tempDescription >> 1);
				slotCount = MM_Bits::populationCount(description);
			} else {
				UDATA *descriptionPtr = (UDATA *) tempDescription;
				while (scanLimit > 0) {
					UDATA description = *descriptionPtr;
					descriptionPtr += 1;
					slotCount += MM_Bits::populationCount(description);
					scanLimit = scanLimit - J9_OBJECT_DESCRIPTION_SIZE;
				}
			}
		}
		return slotCount;
	}
};

#endif /* CLASSMODEL_HPP_ */
