/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * Universal Singleton
 *
 * This abstract class provides a mechanism to manage singleton instances of various types.
 */
public inherited sharing abstract class AFFSingleton {
  
  // Map to store singleton instances keyed by their Type
  private static final Map<Type, Object> SINGLETON_INSTANCE_MAP = new Map<Type, Object>();

  /**
   * Returns the singleton instance of the given type.
   * If the instance does not exist, it creates a new one and stores it in the map.
   *
   * @param type The Type of the singleton to return.
   * @return The singleton instance of the given type.
   */
  public static Object getInstance(Type type) {
    Object instance = SINGLETON_INSTANCE_MAP.get(type);
    if (instance == null) {
      instance = type.newInstance();
      SINGLETON_INSTANCE_MAP.put(type, instance);
    }
    return instance;
  }

  /**
   * Returns the singleton instance of the given type name.
   * If the instance does not exist, it creates a new one and stores it in the map.
   *
   * Note: This method is not intended for use in managed packages.
   *
   * @param fqTypeName The fully qualified type name with namespace if needed.
   * @return The singleton instance of the given type.
   * @throws TypeException if the type cannot be found.
   */
  public static Object getInstance(String typeName) {
    Type type = Type.forName(typeName);
    if (type == null) {
      throw new TypeException('Type not found: ' + typeName);
    }
    return getInstance(type);
  }
}
